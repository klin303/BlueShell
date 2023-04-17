(int : (int : int a) = (int : 1));
(int : (int : int b) = (int : 2));
(int : (int : a) + (int : b));
(int : (int : a) * (int : b));
(float : (float : float x) = (float : 5.0));
(float : (float : float y) = (float : 6.2));
(float : (float : x) + (float : y));
(float : (float : x) * (float : y));
(exec : (exec : exec e1) = (exec : <(string : "echo") withargs (list of string : [(string : "1")])>));
(exec : (exec : exec e2) = (exec : <(string : "echo") withargs (list of string : [(string : "1")])>));
(exec : (exec : e1) + (exec : e2));
(exec : (exec : e1) * (exec : e2));

