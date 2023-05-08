exec e1;
exec e;
exec e2 = e1 | e;
e1 = <"program" withargs [[a, b, c], "hello", 24]>;
e3 = <"hello" withargs []>;
$e1 = "string";
$e1 = 1;
./e;
./e + e;
./e1;
path;

