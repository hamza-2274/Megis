#ifndef IO_FLOW_MEGIS_H
#define IO_FLOW_MEGIS_H

#include "IO_Flow_Base.h"
#include <string>
#include <queue> // REQUIRED for Pipelining

namespace Host_Components
{
    enum class MegIS_State {
        INITIALIZING,
        IDLE,               // Waiting for CPU to finish a bucket
        DATA_TRANSFER,      // Sending MEGIS_WRITE
        SSD_PROCESSING,     // Sending MEGIS_STEP
        COMPLETED
    };

    class IO_Flow_MegIS : public IO_Flow_Base
    {
    public:
        IO_Flow_MegIS(const sim_object_id_type &name, uint16_t flow_id,
                      LHA_type start_lsa_on_device, LHA_type end_lsa_on_device,
                      uint16_t io_queue_id, uint16_t nvme_submission_queue_size,
                      uint16_t nvme_completion_queue_size,
                      IO_Flow_Priority_Class::Priority priority_class,
                      sim_time_type stop_time, unsigned int total_req_count,
                      HostInterface_Types SSD_device_type, PCIe_Root_Complex *pcie_root_complex, SATA_HBA *sata_hba,
                      bool enabled_logging, sim_time_type logging_period, std::string logging_file_path);
        ~IO_Flow_MegIS();

        // Standard overrides
        Host_IO_Request *Generate_next_request();
        void NVMe_consume_io_request(Completion_Queue_Entry *);
        void Start_simulation();
        void Validate_simulation_config();
        void Execute_simulator_event(MQSimEngine::Sim_Event *); // CPU Timer Event
        void Get_statistics(Utils::Workload_Statistics &stats, LPA_type (*Convert_host_logical_address_to_device_address)(LHA_type lha),
                            page_status_type (*Find_NVM_subunit_access_bitmap)(LHA_type lha));

    private:
        MegIS_State current_state;

        // Configuration
        unsigned int total_buckets;
        sim_time_type host_computation_time;
        unsigned int bucket_size_sectors;

        // PIPELINE STATE VARIABLES
        std::queue<unsigned int> sorted_bucket_queue; // Buffer between Host and SSD
        unsigned int buckets_sorted_so_far;           // CPU Progress counter
        unsigned int buckets_processed_by_ssd;        // SSD Progress counter
        unsigned int sectors_written_current_bucket;
        bool is_ssd_busy;                             // Is SSD currently occupied?
    };
}

#endif // IO_FLOW_MEGIS_H