module nngd.nngtests;

public {
    
    import nngd.nngtests.test00;
    import nngd.nngtests.test01;
    import nngd.nngtests.test02;
    import nngd.nngtests.test03;
    import nngd.nngtests.test04;
    
    static immutable string[] testlist = (){
        return [ 
            nngd.nngtests.test00._testclass,
            nngd.nngtests.test01._testclass,
            nngd.nngtests.test02._testclass,
            nngd.nngtests.test03._testclass,
            nngd.nngtests.test04._testclass
        ];    
    }();


}

