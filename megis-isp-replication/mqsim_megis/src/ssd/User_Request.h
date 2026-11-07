#ifndef USER_REQUEST_H
#define USER_REQUEST_H

#include <string>
#include <list>
#include "SSD_Defs.h"
#include "../sim/Sim_Defs.h"
#include "Host_Interface_Defs.h"
#include "NVM_Transaction.h"

namespace SSD_Components
{
    // [MEGIS] Update Enum to support new types
    enum class UserRequestType { 
        READ, 
        WRITE, 
        MEGIS_INIT, 
        MEGIS_STEP, 
        MEGIS_WRITE 
    };

    class NVM_Transaction;
    class User_Request
    {
    public:
        User_Request();
        IO_Flow_Priority_Class::Priority Priority_class;
        io_request_id_type ID;
        LHA_type Start_LBA;

        sim_time_type STAT_InitiationTime;
        sim_time_type STAT_ResponseTime;
        std::list<NVM_Transaction*> Transaction_list;
        unsigned int Sectors_serviced_from_cache;

        unsigned int Size_in_byte;
        unsigned int SizeInSectors;
        UserRequestType Type;    // #
        stream_id_type Stream_id;
        bool ToBeIgnored;
        void* IO_command_info; // used to store host I/O command info
        void* Data;

        // ---------------- MEGIS PARAMETERS ----------------
        // Added to store data decoded from the NVMe Command (SQE)
        
        uint64_t MegIS_Memory_Address = 0; // For MEGIS_INIT
        uint64_t MegIS_Memory_Size = 0;    // For MEGIS_INIT
        uint16_t MegIS_Step_ID = 0;        // For MEGIS_STEP
        // --------------------------------------------------

    private:
        static unsigned int lastId;
    };
}

#endif // !USER_REQUEST_H