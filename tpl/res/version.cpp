namespace
{

#define declare_metadata(name, value) \
	constexpr char _##name[] __attribute__((used, section(".meta."#name))) = value;

declare_metadata(CompanyName, "@RC_CompanyName@")
declare_metadata(FileDescription, "@RC_FileDescription@")
declare_metadata(FileVersion, "@RC_FileVersion@")
declare_metadata(InternalName, "@RC_InternalName@")
declare_metadata(Compiler, "@RC_Compiler@")
declare_metadata(ProductName, "@RC_ProductName@")
declare_metadata(ProductVersion, "@RC_ProductVersion@")
declare_metadata(Comments, "@RC_Comments@");
declare_metadata(BuildDateTime, "@RC_BuildDateTime@");

}// namespace

