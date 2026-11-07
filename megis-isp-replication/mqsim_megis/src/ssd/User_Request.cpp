#include "User_Request.h"

namespace SSD_Components
{
	unsigned int User_Request::lastId = 0;

	User_Request::User_Request() : Sectors_serviced_from_cache(0)
	{
		ID = "" + std::to_string(lastId++);
		ToBeIgnored = false;

		// [MEGIS] Initialize new parameters to 0
		MegIS_Memory_Address = 0;
		MegIS_Memory_Size = 0;
		MegIS_Step_ID = 0;
	}
}