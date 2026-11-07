#include "../sim/Engine.h"
#include "IO_Flow_MegIS.h"
#include "Host_Defs.h"

namespace Host_Components
{
    IO_Flow_MegIS::IO_Flow_MegIS(const sim_object_id_type &name, uint16_t flow_id,
                                 LHA_type start_lsa_on_device, LHA_type end_lsa_on_device,
                                 uint16_t io_queue_id, uint16_t nvme_submission_queue_size,
                                 uint16_t nvme_completion_queue_size,
                                 IO_Flow_Priority_Class::Priority priority_class,
                                 sim_time_type stop_time, unsigned int total_req_count,
                                 HostInterface_Types SSD_device_type, PCIe_Root_Complex *pcie_root_complex, SATA_HBA *sata_hba,
                                 bool enabled_logging, sim_time_type logging_period, std::string logging_file_path)
        : IO_Flow_Base(name, flow_id, start_lsa_on_device, end_lsa_on_device, io_queue_id,
                       nvme_submission_queue_size, nvme_completion_queue_size, priority_class,
                       stop_time, 0, total_req_count, SSD_device_type, pcie_root_complex, sata_hba,
                       enabled_logging, logging_period, logging_file_path)
    {
        // Initialization
        this->current_state = MegIS_State::INITIALIZING;
        this->total_buckets = 10;
        this->host_computation_time = 5000000; // 5ms sorting latency
        this->bucket_size_sectors = 2048;      // 1MB per bucket
        
        // Pipeline Init
        this->buckets_sorted_so_far = 0;
        this->buckets_processed_by_ssd = 0;
        this->is_ssd_busy = false;
        this->sectors_written_current_bucket = 0;
    }

    IO_Flow_MegIS::~IO_Flow_MegIS() {}

    // 1. START SIMULATION
    void IO_Flow_MegIS::Start_simulation()
    {
        IO_Flow_Base::Start_simulation();

        // A. Send INIT Command
        Host_IO_Request* req = new Host_IO_Request;
        req->Type = Host_IO_Request_Type::MEGIS_INIT;
        req->Start_LBA = start_lsa_on_device;
        req->LBA_count = 1;
        req->MegIS_Memory_Address = MEGIS_HOST_BUFFER_BASE;
        req->MegIS_Memory_Size = MEGIS_MAX_HOST_BUFFER;
        req->Arrival_time = Simulator->Time();
        
        STAT_generated_megis_init_count++;
        Submit_io_request(req);

        // B. Start the CPU Sorting Loop (Step 1)
        // Schedule the first "Sort Finished" event in the future
        Simulator->Register_sim_event(Simulator->Time() + host_computation_time, this, 0, 0);
    }

    // 2. CPU THREAD: Handles "Sort Finished" Events
    void IO_Flow_MegIS::Execute_simulator_event(MQSimEngine::Sim_Event* event)
    {
        // A bucket has finished sorting!
        buckets_sorted_so_far++;
        
        // A. Push to Queue (Buffer)
        sorted_bucket_queue.push(buckets_sorted_so_far);

        // B. PIPELINING: Immediately start sorting the NEXT bucket
        // This ensures CPU keeps working even if SSD is busy 
        if (buckets_sorted_so_far < total_buckets) {
            Simulator->Register_sim_event(Simulator->Time() + host_computation_time, this, 0, 0);
        }

        // C. Check SSD: If idle, wake it up to process the new bucket
        if (!is_ssd_busy && !sorted_bucket_queue.empty()) {
            current_state = MegIS_State::DATA_TRANSFER;
            is_ssd_busy = true;
            sectors_written_current_bucket = 0;
            
            // Trigger the write loop
            Host_IO_Request* req = Generate_next_request();
            if (req) Submit_io_request(req);
        }
    }

    // 3. GENERATOR: Creates Write Requests
    Host_IO_Request* IO_Flow_MegIS::Generate_next_request()
    {
        if (current_state == MegIS_State::DATA_TRANSFER) {
            Host_IO_Request* req = new Host_IO_Request;
            req->Type = Host_IO_Request_Type::MEGIS_WRITE;
            
            unsigned int max_chunk = 128; // 64KB chunks
            unsigned int remaining = bucket_size_sectors - sectors_written_current_bucket;
            unsigned int chunk_size = (remaining < max_chunk) ? remaining : max_chunk;

            req->LBA_count = chunk_size;
            req->Start_LBA = start_lsa_on_device + sectors_written_current_bucket;
            req->MegIS_Bucket_ID = sorted_bucket_queue.front(); 
            req->Arrival_time = Simulator->Time();

            sectors_written_current_bucket += chunk_size;
            STAT_generated_megis_write_count++;
            
            return req;
        }
        return NULL;
    }

    // 4. CONSUMER: Handles SSD Completions
    void IO_Flow_MegIS::NVMe_consume_io_request(Completion_Queue_Entry* cqe)
    {
        IO_Flow_Base::NVMe_consume_io_request(cqe);
        IO_Flow_Base::NVMe_update_and_submit_completion_queue_tail();

        switch (current_state) {
            case MegIS_State::INITIALIZING:
                // Init done. Go to IDLE and wait for CPU events.
                current_state = MegIS_State::IDLE; 
                break;

            case MegIS_State::DATA_TRANSFER:
                // Check if bucket transfer is complete
                if (sectors_written_current_bucket >= bucket_size_sectors) {
                    // Transfer Done. Tell SSD to Start Step 2 (Intersection)
                    current_state = MegIS_State::SSD_PROCESSING;
                    
                    Host_IO_Request* step_req = new Host_IO_Request;
                    step_req->Type = Host_IO_Request_Type::MEGIS_STEP;
                    step_req->MegIS_Step_ID = 2; // Trigger Intersection
                    step_req->Start_LBA = start_lsa_on_device; 
                    step_req->LBA_count = 1;
                    step_req->Arrival_time = Simulator->Time();
                    
                    STAT_generated_megis_step_count++;
                    Submit_io_request(step_req);
                } else {
                    // Continue writing chunks
                    Host_IO_Request* next = Generate_next_request();
                    if (next) Submit_io_request(next);
                }
                break;

            case MegIS_State::SSD_PROCESSING:
                // SSD finished processing the bucket
                buckets_processed_by_ssd++;
                sorted_bucket_queue.pop(); // Remove processed bucket from queue
                
                if (buckets_processed_by_ssd >= total_buckets) {
                    current_state = MegIS_State::COMPLETED;
                    PRINT_MESSAGE("MegIS Analysis Completed Successfully.");
                } 
                else if (!sorted_bucket_queue.empty()) {
                    // Pipeline Check: Is another bucket already waiting in queue?
                    // Yes -> Immediately start transferring it.
                    current_state = MegIS_State::DATA_TRANSFER;
                    sectors_written_current_bucket = 0;
                    
                    Host_IO_Request* next = Generate_next_request();
                    if (next) Submit_io_request(next);
                } 
                else {
                    // No -> Queue empty. Wait for CPU to finish sorting.
                    current_state = MegIS_State::IDLE;
                    is_ssd_busy = false;
                }
                break;
                
            default: break;
        }
    }

    void IO_Flow_MegIS::Validate_simulation_config() {}

    void IO_Flow_MegIS::Get_statistics(Utils::Workload_Statistics& stats, LPA_type(*Convert_host_logical_address_to_device_address)(LHA_type lha),
        page_status_type(*Find_NVM_subunit_access_bitmap)(LHA_type lha))
    {
        stats.Type = Utils::Workload_Type::SYNTHETIC;
    }
}