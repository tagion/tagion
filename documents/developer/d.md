WIP:

Walter Bright:  
https://en.wikipedia.org/wiki/Walter_Bright

Core design of the D specially D2:  
https://research.nvidia.com/person/andrei-alexandrescu  

https://en.wikipedia.org/wiki/D_(programming_language)  
https://dlang.org  

# Why dlang


D is a very power full language with a simple and readable syntax (C like syntax).
Same power as C++ with better or more extensive support for meta-programming, introspection and CTFE.
D language includes contract-program (pre,post-conditions) unittest no external tool needed.
D namespacing and simpler  because you modules/import instead for #include (edited) 
D doesn't use macros "#define" in templates and [CTFE](https://tour.dlang.org/tour/en/gems/compile-time-function-evaluation-ctfe "Compile Time Function Evaluation") instead. Which makes the code more readable and easier to debug
D support multi-threading out of the box with (shared, immutable, synchronized, TLS etc, thread constructor and dtors and others)
And not really related to the D language but the standard library is not based on container class structure but on meta-function and introspection. This means that it's more flexible for any paradigm you choose to program in.
