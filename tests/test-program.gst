int x = 2;
int y = 3;
if (true)
{
x = y;
}
else
{
y = x + foo(x);
}
return 0;

int foo(int x)
{
return x + x;
}
