exec e1;
exec e;

e1 = "program" {[a, b, c], "hello", 24};
$e1 = "string";
exit_code = e?;
$e1 = 1;
e1? = 1;
path = $e1;
./e;
./e + e;
./e1;
path;
e1[1 + 1];

