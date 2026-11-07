#ifndef HOST_IO_REQUEST_H
#define HOST_IO_REQUEST_H

#include "../ssd/SSD_Defs.h"

namespace Host_Components
{
    enum class Host_IO_Request_Type {
        READ,
        WRITE,
        MEGIS_INIT,    // Initialize analysis & set result buffer
        MEGIS_STEP,    // Sync signal (Host -> SSD) to trigger hardware steps
        MEGIS_WRITE    // Transfer K-mer buckets (updates MegIS FTL)
    };

    class Host_IO_Request {
    public:
        // Standard MQSim Members
        sim_time_type Arrival_time;
        sim_time_type Enqueue_time;
        LHA_type Start_LBA;      //// Acts as Sequence Number
        unsigned int LBA_count;  //// Acts as Batch/Chunk Size for WRITE TOO 
        Host_IO_Request_Type Type;
        uint16_t IO_queue_info;
        uint16_t Source_flow_id;//// Acts as Session ID

        // ---------------- MEGIS PARAMETERS ----------------
        
        // 1. For MEGIS_INIT
        // Defines where in Host DRAM the SSD should write the final results (TaxIDs)
        uint64_t MegIS_Memory_Address = 0; 
        uint64_t MegIS_Memory_Size = 0;    

        // 2. For MEGIS_STEP
        // Specifies which step to trigger (1 = Extraction/Sorting, 2 = Intersection, 3 = Index)
        uint16_t MegIS_Step_ID = 0;

        // 3. For MEGIS_WRITE
        // While Start_LBA covers the address, you might need to track which bucket 
        // this write belongs to for simulation statistics.
        uint32_t MegIS_Bucket_ID = 0; 
    };
}

#endif // !HOST_IO_REQUEST_H