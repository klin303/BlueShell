bar(foo);
hello(world);
kenny(lin);

int foo()
{
return 1;
}

int bar(function (int) foo)
{
return foo(1);
}

int world(string s)
{
return 1;
}

int hello(function (string -> int) foo)
{
return foo("hi");
}

int lin(string s, exec c)
{
return 1;
}

int kenny(function (string -> exec -> int) foo)
{
return foo("hi", <"ls" withargs []>);
}
