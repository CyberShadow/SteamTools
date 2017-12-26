import ae.sys.persistence.keyvalue;

import steamcmd;
import vdf;

VDF getPackageInfoCached(ref SteamCMD steam, int id) { return packages.getOrAdd(id, steam.getPackageInfo(id)); }
VDF getAppInfoCached(ref SteamCMD steam, int id) { return apps.getOrAdd(id, steam.getAppInfo(id)); }

private:

KeyValueDatabase db;
KeyValueStore!(int, VDF) packages, apps;

static this()
{
	db = KeyValueDatabase("cache.s3db");
	packages = KeyValueStore!(int, VDF)(&db, "packages");
	apps = KeyValueStore!(int, VDF)(&db, "apps");
}
