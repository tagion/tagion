# Tagion basic module
The contains the Tagion basic modules which is common for Tagion network.

This is contain the the submodul of the tagion_main repository.



The Basic module contains *template function* and other support functions generally used in the Tagion network.

This module also contains the *TagionException* which is the basic Exception object use by all other Tagion modules. This exception object keeps track of the *taskname* in witch the Exception is thrown. 



This module is compile as.

```bash
make lib
```

Which generated the *bin/tagion_basic.a* archive.

The source code is distributed under the [LICENSE.md](bloc/master/LICENSE.md)

