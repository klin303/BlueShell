(function (void) : (function (void) : function (void) foo2) = (function (void) : foo));
(void : bar((function (void) : foo)));
(void : hello((function (string -> void) : world)));
(void : kenny((function (string -> exec -> void) : lin)));

void foo()
{
}

void bar(function (void) foo)
{
}

void world(string s)
{
}

void hello(function (string -> void) foo)
{
}

void lin(string s, exec c)
{
}

void kenny(function (string -> exec -> void) foo)
{
}
