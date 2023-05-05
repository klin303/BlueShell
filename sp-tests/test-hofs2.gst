function (string -> exec -> int) foo = lin;
int x = foo("hi", <"ls" withargs []>);

int lin(string s, exec c)
{
return 1;
}
