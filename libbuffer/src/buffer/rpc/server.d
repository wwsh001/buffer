module buffer.rpc.server;

import std.traits;
import std.algorithm.searching;
import std.conv : to;
import std.variant;

import buffer.message;

class Server(Business)
{
    static immutable string[] builtinFunctions = [ "__ctor", "__dtor", "opEquals", "opCmp", "toHash", "toString", "Monitor", "factory" ];
    Business business = new Business();

    ubyte[] Handler(ubyte[] data)
    {
        ushort messageId;
        TypeInfo_Class messageClass;
        string method;
        Variant[] params = Message.deserialize(data, messageId, messageClass, method);

        if ((messageClass is null) || (params is null))
        {
            return null;
        }

        foreach (member; __traits(allMembers, Business))
        {
            alias MemberFunctionsTuple!(Business, member) funcs;

            static if (funcs.length > 0 && !canFind(builtinFunctions, member))
            {
                static assert(funcs.length == 1, "The function of RPC call doesn't allow the overloads, function: " ~ member);

                alias typeof(funcs[0]) func;
                alias ParameterTypeTuple!func ParameterTypes;
                alias ReturnType!func RT;

                mixin(`
                    if (method == "` ~ member ~ `")
                    {
                        assert(` ~ ParameterTypes.length.to!string ~ ` == params.length, "Incorrect number of parameters, ` ~ member ~ ` requires ` ~ ParameterTypes.length.to!string ~ ` parameters.");

                        RT msg_ret = business.` ~ member ~ `(` ~ CombinationParams!ParameterTypes ~ `);
                        return msg_ret.serialize();
                    }
                `);
            }
        }

        assert(0, "The server does not implement client call method: " ~ method);
    }

    static string CombinationParams(ParameterTypes...)()
    {
        string s;

        foreach (i, type; ParameterTypes)
        {
            if (i > 0)
                s ~= ", ";
            s ~= ("params[" ~ i.to!string ~ "].get!" ~ type.stringof);
        }

        return s;
    }
}