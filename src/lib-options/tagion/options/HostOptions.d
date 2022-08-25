module tagion.options.HostOptions;

struct HostOptions
{
    import tagion.utils.JSONCommon : JSONCommon;

    ulong timeout;
    uint max_size;
    mixin JSONCommon;
}
