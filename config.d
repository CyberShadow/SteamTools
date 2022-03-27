import ae.utils.sini;

struct Config
{
	string credentials;
	ulong accountId;
	string steamPath = "~/.local/share/Steam";
	string cookies;
	string steamcmd = "steamcmd";
}

Config getConfig() { return loadIni!Config("config.ini"); }
