module tagion.testbench.tools.utils;
import tagion.utils.JSONCommon;


struct Genesis {
	int bills;
	double amount;
	mixin JSONCommon;
}
