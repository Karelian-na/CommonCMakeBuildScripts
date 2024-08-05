#include <iostream>

#ifdef dynamic_EXPORTS
#	ifdef _MSC_VER
#		define DYNAMIC_API __declspec(dllexport)
#	else
#		define DYNAMIC_API __attribute((visibility("default")))
#	endif
#else
#	ifdef _MSC_VER
#		define DYNAMIC_API __declspec(dllimport)
#	else
#		define DYNAMIC_API
#	endif
#endif

class DYNAMIC_API Dynamic {
public:
	Dynamic();
	~Dynamic();
};
