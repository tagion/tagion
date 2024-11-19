module nngd.nngtests;
version (unittest) {
}
else {
    pragma(msg, "This breaks the unittest so it's disabled");

    public {

        import nngd.nngtests.testdata;
        import nngd.nngtests.test00;
        import nngd.nngtests.test01;
        import nngd.nngtests.test02;
        import nngd.nngtests.test03;
        import nngd.nngtests.test04;
        import nngd.nngtests.test05;
        import nngd.nngtests.test06;
        import nngd.nngtests.test07;
        import nngd.nngtests.test08;
        import nngd.nngtests.test09;
        import nngd.nngtests.test10;

        static immutable string[] testlist = () {
            return [
                nngd.nngtests.test00._testclass,
                nngd.nngtests.test01._testclass,
                nngd.nngtests.test02._testclass,
                nngd.nngtests.test03._testclass,
                nngd.nngtests.test04._testclass,
                nngd.nngtests.test05._testclass,
                nngd.nngtests.test06._testclass,
                nngd.nngtests.test07._testclass,
                nngd.nngtests.test08._testclass,
                nngd.nngtests.test09._testclass,
                nngd.nngtests.test10._testclass
            ];
        }();

    }
}
