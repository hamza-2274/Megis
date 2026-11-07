#ifndef FTL_H
#define FTL_H

#include "../sim/Sim_Reporter.h"
#include "../utils/RandomGenerator.h"
#include "NVM_Firmware.h"
#include "TSU_Base.h"
#include "Address_Mapping_Unit_Base.h"
#include "Flash_Block_Manager_Base.h"
#include "GC_and_WL_Unit_Base.h"
#include "NVM_PHY_ONFI.h"
#include "Stats.h"
#include "User_Request.h" // [MEGIS EDIT] Required to see User_Request fields

namespace SSD_Components
{
    enum class SimulationMode { STANDALONE, FULL_SYSTEM };

    class Flash_Block_Manager_Base;
    class Address_Mapping_Unit_Base;
    class GC_and_WL_Unit_Base;
    class TSU_Base;
    class Host_Interface_Base; // [MEGIS EDIT] Forward declaration

    class FTL : public NVM_Firmware
    {
    public:
        FTL(const sim_object_id_type& id, Data_Cache_Manager_Base* data_cache, 
            unsigned int channel_no, unsigned int chip_no_per_channel, unsigned int die_no_per_chip, unsigned int plane_no_per_die, 
            unsigned int block_no_per_plane, unsigned int page_no_per_block, unsigned int page_size_in_sectors, 
            sim_time_type avg_flash_read_latency, sim_time_type avg_flash_program_latency, double over_provisioning_ratio, unsigned int max_allowed_block_erase_count, int seed);
        ~FTL();
        void Perform_precondition(std::vector<Utils::Workload_Statistics*> workload_stats);
        void Validate_simulation_config();
        void Start_simulation();
        void Execute_simulator_event(MQSimEngine::Sim_Event*);
        LPA_type Convert_host_logical_address_to_device_address(LHA_type lha);
        page_status_type Find_NVM_subunit_access_bitmap(LHA_type lha);
        
        Address_Mapping_Unit_Base* Address_Mapping_Unit;
        Flash_Block_Manager_Base* BlockManager;
        GC_and_WL_Unit_Base* GC_and_WL_Unit;
        TSU_Base * TSU;
        NVM_PHY_ONFI* PHY;
        
        // [MEGIS EDIT START] - Link to Host Interface for sending completions
        Host_Interface_Base* HostInterface; 

        // [MEGIS EDIT START] - The "Brain" Functions
        void Process_MegIS_Request(User_Request* req);
        // [MEGIS EDIT END]
        // [MEGIS EDIT START] - Section 4.5 L2P Mapping Scheme
        struct MegIS_L2P_Entry {
        uint64_t start_LPA;           // Starting logical page of the DB
        uint32_t start_PBA;           // Starting physical block
        uint64_t database_size;       // Total size in pages
        std::vector<uint32_t> block_sequence;  // Sequence of blocks (Coarse-grained map)
    };
    static const int MEGIS_EVT_ID = 9999; // [MEGIS FIX] moved out of MegIS_L2P_Entry so FTL::MEGIS_EVT_ID resolves

    bool megis_mode = false;          // Mode flag
    MegIS_L2P_Entry megis_mapping;    // The specialized mapping table
    // [MEGIS EDIT END]
        void Report_results_in_XML(std::string name_prefix, Utils::XmlWriter& xmlwriter);

    private:
        unsigned int channel_no, chip_no_per_channel, die_no_per_chip, plane_no_per_die;
        unsigned int block_no_per_plane, page_no_per_block, page_size_in_sectors;
        unsigned int max_allowed_block_erase_count;
        int preconditioning_seed;
        Utils::RandomGenerator random_generator;
        double over_provisioning_ratio;
        sim_time_type avg_flash_read_latency;
        sim_time_type avg_flash_program_latency;

        // [MEGIS EDIT START] - Internal State
        uint64_t megis_output_buffer_address;
        uint64_t megis_output_buffer_size;
        User_Request* megis_pending_request; // The request currently being processed
        // [MEGIS EDIT END]
    };
}

#endif // !FTL_H