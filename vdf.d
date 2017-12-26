import std.array;
import std.exception;

import ae.utils.array;

struct VDF
{
	string key;

	// Exactly one of these is non-null:
	string value;
	VDF[] nodes;

	VDF* opIn_r(string s)
	{
		foreach (ref node; nodes)
			if (node.key == s)
				return &node;
		return null;
	}

	ref VDF opIndex(string s)
	{
		auto pnode = s in this;
		if (pnode)
			return *pnode;
		throw new Exception("No such VDF key: " ~ s);
	}

	// Don't forget to populate value or nodes!
	ref VDF getOrAdd(string s)
	{
		auto pnode = s in this;
		if (pnode)
			return *pnode;
		nodes ~= VDF(s);
		return nodes[$-1];
	}
}

VDF parseVDF(string s)
{
	auto os = s;
	scope(failure) { import std.file; write("bad.vdf", os); }

	char read()
	{
		enforce(s.length, "Unexpected end of string");
		return s.shift();
	}

	void expect(char expected)
	{
		auto got = read();
		enforce(expected == got, "Expected " ~ expected ~ ", got " ~ got);
	}

	string readString()
	out
	{
		assert(__result !is null);
	}
	body
	{
		expect('"');
		string result = ""; // Non-null
		bool escape;
		while (true)
		{
			auto c = read;
			if (escape || c != '\\')
			{
				if (c == '"' && !escape)
					return result;
				result ~= c;
				escape = false;
			}
			else
				escape = true;
		}
	}

	void readIndent(int indent)
	{
		foreach (n; 0..indent)
			expect('\t');
	}

	VDF readNode(int indent)
	out
	{
		assert(!__result.value != !__result.nodes);
	}
	body
	{
		VDF node;
		node.key = readString();
		scope(failure) { import std.stdio; stderr.writeln("Error reading node " ~ node.key ~ ":"); }
		switch (read())
		{
			case '\n':
			{
				readIndent(indent);
				expect('{');
				expect('\n');
				node.nodes = emptySlice!VDF;
				while (true)
				{
					readIndent(indent);
					switch (read())
					{
						case '}':
							expect('\n');
							return node;
						case '\t':
							node.nodes ~= readNode(indent+1);
							break;
						default:
							throw new Exception("Expected } of tab in child indent");
					}
				}
			}
			case '\t':
			{
				expect('\t');
				node.value = readString();
				expect('\n');
				return node;
			}
			default:
				throw new Exception("Expected newline of tab after key name");
		}
	}

	VDF root;
	while (s.length)
		root.nodes ~= readNode(0);
	return root;
}

string generateVDF(in VDF vdf)
{
	Appender!string buf;

	void putString(string s)
	{
		buf.put('"');
		foreach (c; s)
			if (c == '"')
				buf.put(`\"`);
			else
				buf.put(c);
		buf.put('"');
	}

	void putIndent(int indent)
	{
		foreach (n; 0..indent)
			buf.put('\t');
	}

	void putNode(in ref VDF vdf, int indent)
	{
		scope(failure) { import std.stdio; stderr.writeln("Error serializing node " ~ vdf.key ~ ":"); }
		putIndent(indent);
		putString(vdf.key);

		enforce(!vdf.value != !vdf.nodes, "Exactly one of value and nodes must be null");
		if (vdf.value)
		{
			buf.put("\t\t");
			putString(vdf.value);
			buf.put("\n");
		}
		else
		{
			buf.put("\n");
			putIndent(indent);
			buf.put("{\n");
			foreach (child; vdf.nodes)
				putNode(child, indent + 1);
			putIndent(indent);
			buf.put("}\n");
		}
	}

	assert(vdf.key is null, "Non-null root node key");
	foreach (ref child; vdf.nodes)
		putNode(child, 0);

	return buf.data;
}
