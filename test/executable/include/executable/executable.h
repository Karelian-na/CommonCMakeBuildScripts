#include <iostream>

class Executable {
public:
	Executable() {
		std::cout << "Hello";
	}
	~Executable() {
		std::cout << "word";
	}
};
