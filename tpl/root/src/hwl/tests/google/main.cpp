#include <gtest/gtest.h>
#include <unistd.h>

int main(int argc, char* argv[])
{
	::testing::InitGoogleTest(&argc, argv);
	auto retval = RUN_ALL_TESTS();
	// A delay for observing the test order.
	::sleep(1);
	return retval;
}
