const char *CLHash_Utilities_kern_source =
"static inline unsigned int intintHash_CompressIdentity(char data, int hashCode){ return hashCode; }\n"
"typedef struct intintHash_CompressLCGData{ \n"
"    long unsigned int a;\n"
"    long unsigned int c;\n"
"    unsigned int m;\n"
"    unsigned int n;\n"
"}intintHash_CompressLCGData;\n"
"\n"
"static inline unsigned int intintHash_CompressLCG(intintHash_CompressLCGData compressLCGData, int hashCode){\n"
"    return ((compressLCGData.a * hashCode + compressLCGData.c) % compressLCGData.m) % compressLCGData.n; \n"
"}\n"
"\n"
"typedef struct intintLCGQuadraticOpenCompactCLHash_TableData{ \n"
"    int hashID;\n"
"    unsigned int numBuckets;\n"
"    intintHash_CompressLCGData compressFuncData;\n"
"}intintLCGQuadraticOpenCompactCLHash_TableData; \n"
"\n"
"typedef struct intintLCGQuadraticOpenCompactCLHash_Bucket{\n"
"    int key; \n"
"    int value; \n"
"}intintLCGQuadraticOpenCompactCLHash_Bucket; \n"
"\n"
"__kernel void intintLCGQuadraticOpenCompactCLHash_Empty(__global char *tableData){ \n"
"    uint index = get_global_id(0); \n"
"    if(index >= ((__global intintLCGQuadraticOpenCompactCLHash_TableData*)tableData)->numBuckets){ \n"
"        return; \n"
"    } \n"
"    __global intintLCGQuadraticOpenCompactCLHash_Bucket *buckets \n"
"    = (__global intintLCGQuadraticOpenCompactCLHash_Bucket*)\n"
"      &tableData[sizeof(intintLCGQuadraticOpenCompactCLHash_TableData)]; \n"
"      buckets[index].key = UINT_MAX;\n"
"}\n"
"\n"
"typedef struct intintIdentityPerfectCLHash_TableData{ \n"
"    int hashID; \n"
"    unsigned int numBuckets; \n"
"    char compressFuncData;\n"
"}intintIdentityPerfectCLHash_TableData; \n"
"\n"
"typedef struct intintIdentityPerfectCLHash_Bucket{ \n"
"    int key; \n"
"    int value; \n"
"}intintIdentityPerfectCLHash_Bucket; \n"
"\n"
"__kernel void intintIdentityPerfectCLHash_Empty(__global char *tableData){ \n"
"    uint index = get_global_id(0); \n"
"    if(index >= ((__global intintIdentityPerfectCLHash_TableData*)tableData)->numBuckets){ return; } \n"
"    __global intintIdentityPerfectCLHash_Bucket *buckets \n"
"      = (__global intintIdentityPerfectCLHash_Bucket*)\n"
"        &tableData[sizeof(intintIdentityPerfectCLHash_TableData)]; \n"
"    buckets[index].key = UINT_MAX;\n"
"}\n"
"\n"
"typedef struct intintIdentitySentinelPerfectCLHash_TableData{ \n"
"    int hashID; \n"
"    unsigned int numBuckets; \n"
"    char compressFuncData; \n"
"    uint emptyValue; \n"
"}intintIdentitySentinelPerfectCLHash_TableData;\n"
" \n"
"typedef struct intintIdentitySentinelPerfectCLHash_Bucket{ uint value; }\n"
"intintIdentitySentinelPerfectCLHash_Bucket; \n"
"\n"
"__kernel void intintIdentitySentinelPerfectCLHash_Empty(__global char *tableData){ \n"
"    uint index = get_global_id(0); \n"
"    if(index >= ((__global intintIdentitySentinelPerfectCLHash_TableData*)tableData)->numBuckets){ \n"
"        return;\n"
"    }\n"
"    __global intintIdentitySentinelPerfectCLHash_Bucket *buckets \n"
"      = (__global intintIdentitySentinelPerfectCLHash_Bucket*)\n"
"        &tableData[sizeof(intintIdentitySentinelPerfectCLHash_TableData)];\n"
"    buckets[index].value \n"
"      = ((__global intintIdentitySentinelPerfectCLHash_TableData*)tableData)->emptyValue; \n"
"}\n"
"\n"
"typedef struct intintLCGLinearOpenCompactCLHash_TableData{ \n"
"    int hashID; \n"
"    unsigned int numBuckets; \n"
"    intintHash_CompressLCGData compressFuncData;\n"
"}intintLCGLinearOpenCompactCLHash_TableData; \n"
"\n"
"typedef struct intintLCGLinearOpenCompactCLHash_Bucket{ \n"
"    int key; \n"
"    int value; \n"
"}intintLCGLinearOpenCompactCLHash_Bucket; \n"
"\n"
"__kernel void intintLCGLinearOpenCompactCLHash_Empty(__global char *tableData){ \n"
"    uint index = get_global_id(0); \n"
"    if(index >= ((__global intintLCGLinearOpenCompactCLHash_TableData*)tableData)->numBuckets){ \n"
"        return; \n"
"    } \n"
"    __global intintLCGLinearOpenCompactCLHash_Bucket *buckets \n"
"      = (__global intintLCGLinearOpenCompactCLHash_Bucket*)\n"
"        &tableData[sizeof(intintLCGLinearOpenCompactCLHash_TableData)];\n"
"    buckets[index].key = UINT_MAX;\n"
"}\n"
;
