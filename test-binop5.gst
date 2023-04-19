(float : (float : float a) = (float : 5.0));
(int : (int : int x) = (int : 5));
(bool : (bool : bool b) = (bool : true));
(string : (string : string str) = (string : "hello"));
(char : (char : char c) = (char : 'c'));
(list of int : (list of int : list of int hahaha) = (list of int : [(int : 1), (int : 2)]));
(exec : (exec : exec e) = (exec : <(string : "echo") withargs (list of string : [(string : "hello world")])>));
(bool : (float : a) == (float : a));
(bool : (int : x) == (int : x));
(bool : (bool : b) != (bool : b));
(bool : (string : str) != (string : str));
(bool : (char : c) == (char : c));
(bool : (list of int : hahaha) != (list of int : hahaha));
(bool : (exec : e) == (exec : e));

