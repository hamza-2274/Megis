#ifndef IO_FLOW_PARAMETER_SET_H
#define IO_FLOW_PARAMETER_SET_H

#include <string>
#include "../nvm_chip/flash_memory/FlashTypes.h"
#include "../ssd/Host_Interface_Defs.h"
#include "../host/IO_Flow_Synthetic.h"
#include "../host/IO_Flow_Trace_Based.h"
#include "../utils/Workload_Statistics.h"
#include "../utils/DistributionTypes.h"
#include "Parameter_Set_Base.h"

// [MEGIS FIX] MQSim defines Flow_Type here and uses it throughout (Host_System.cpp, main.cpp).
// The earlier edit replaced it with a new IO_Flow_Type enum, which left Flow_Type undefined.
// We keep MQSim's enum and add MEGIS to it.
enum class Flow_Type { SYNTHETIC, TRACE, MEGIS };

class IO_Flow_Parameter_Set : public Parameter_Set_Base
{
public:
	SSD_Components::Caching_Mode Device_Level_Data_Caching_Mode;
	Flow_Type Type;
	IO_Flow_Priority_Class::Priority Priority_Class;//The priority class is only considered when the SSD device uses NVMe host interface
	flash_channel_ID_type* Channel_IDs;//Resource partitioning: which channel ids are allocated to this flow
	flash_chip_ID_type* Chip_IDs;//Resource partitioning: which chip ids are allocated to this flow
	flash_die_ID_type* Die_IDs;//Resource partitioning: which die ids are allocted to this flow
	flash_plane_ID_type* Plane_IDs;//Resource partitioning: which plane ids are allocated to this flow
	unsigned int Initial_Occupancy_Percentage;//Percentage of the logical space that is written when preconditioning is performed
	int Channel_No, Chip_No, Die_No, Plane_No;
	void XML_serialize(Utils::XmlWriter& xmlwrite);
	void XML_deserialize(rapidxml::xml_node<> *node);
private:
};

class IO_Flow_Parameter_Set_Synthetic : public IO_Flow_Parameter_Set
{
public:
	IO_Flow_Parameter_Set_Synthetic() { this->Type = Flow_Type::SYNTHETIC; }
	unsigned int Working_Set_Percentage;//Percentage of available storage space that is accessed
	Utils::Request_Generator_Type Synthetic_Generator_Type;
	char Read_Percentage;
	Utils::Address_Distribution_Type Address_Distribution;
	char Percentage_of_Hot_Region;//This parameters used if the address distribution type is hot/cold (i.e., (100-H)% of the whole I/O requests are going to a H% hot region of the storage space)
	bool Generated_Aligned_Addresses;
	unsigned int Address_Alignment_Unit;
	Utils::Request_Size_Distribution_Type Request_Size_Distribution;
	unsigned int Average_Request_Size;//Average request size in sectors
	unsigned int Variance_Request_Size;//Variance of request size in sectors
	//Host_Components::Request_Generator_Type Generator_Type;//Request generator could be time-based 
	int Seed;
	unsigned int Average_No_of_Reqs_in_Queue;//Average number of I/O requests from this flow in the 
	unsigned int Bandwidth;//The bandwidth of I/O flow in bytes per second (it should be a multiplication of sector size)

	sim_time_type Stop_Time;//Defines when to stop generating I/O requests
	unsigned int Total_Requests_To_Generate;//If Stop_Time is equal to zero, then requst generator considers Total_Requests_To_Generate to decide when to stop generating I/O requests
	
	void XML_serialize(Utils::XmlWriter& xmlwriter);
	void XML_deserialize(rapidxml::xml_node<> *node);
};

class IO_Flow_Parameter_Set_Trace_Based : public IO_Flow_Parameter_Set
{
public:
	IO_Flow_Parameter_Set_Trace_Based() { this->Type = Flow_Type::TRACE; }
	std::string File_Path;
	int Percentage_To_Be_Executed;
	int Relay_Count; 
	Trace_Time_Unit Time_Unit;
	
	void XML_serialize(Utils::XmlWriter& xmlwriter);
	void XML_deserialize(rapidxml::xml_node<> *node);
};

// In src/exec/IO_Flow_Parameter_Set.h

// ... existing classes (IO_Flow_Parameter_Set_Synthetic, IO_Flow_Parameter_Set_Trace_Based) ...

// [MEGIS EDIT START] - Add this new class definition
class IO_Flow_Parameter_Set_MegIS : public IO_Flow_Parameter_Set
{
public:
    // [MEGIS FIX] Set the flow type so Host_System creates an IO_Flow_MegIS, and provide the
    // stop condition fields that Host_System passes to the flow (they only exist in the
    // Synthetic/Trace parameter sets otherwise).
    IO_Flow_Parameter_Set_MegIS() : Stop_Time(0), Total_Requests_To_Generate(171) { this->Type = Flow_Type::MEGIS; }
    sim_time_type Stop_Time;                 // 0 = stop by request count
    unsigned int Total_Requests_To_Generate; // 1 INIT + 10 buckets x (16 x 64 KB WRITE + 1 STEP) = 171
    void XML_serialize(Utils::XmlWriter& xmlwriter);
    void XML_deserialize(rapidxml::xml_node<>* node);
};
// [MEGIS EDIT END]

#endif // IO_FLOW_PARAMETER_SET_H