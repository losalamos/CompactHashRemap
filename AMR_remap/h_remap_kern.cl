#pragma OPENCL EXTENSION cl_khr_fp64: enable

#define PROBE_DEPTH 32

#define USE_MACROS

#ifdef USE_MACROS
#define two_to_the(ival)       (1<<(ival) )
#define four_to_the(ival)      (1<<( (ival)*2 ) )
#define key_to_i(key, lev)     ( (key) % two_to_the(lev) )
#define key_to_j(key, lev)     ( (key) / two_to_the(lev) )
#define ij_to_key(i, j, lev)   (((j) * two_to_the(lev)) + (i))
#endif

#ifndef USE_MACROS
inline uint two_to_the(int i){
    if (i>=0){
        return 1<<i;
    }else{
        return -1;
    }
}

inline uint key_to_i (uint key, uint lev) {
    return (key % two_to_the(lev));
}

inline uint key_to_j (uint key, uint lev) {
    return (key / two_to_the(lev));
}

inline uint ij_to_key (uint i, uint j, uint lev) {
    return ((j * two_to_the (lev)) + i);
}
#endif

#define hashval(j,i) hash[(j)*imaxsize+(i)]

__kernel void full_perfect_hash_setup (
                 const uint ncells,
                 const uint mesh_size,
                 const uint max_lev,
        __global const uint *i,
        __global const uint *j,
        __global const uint *level,
        __global       int  *hash){

    const int ic = get_global_id(0);

    if(ic >= ncells) return;

    // Needed for the stride in hashval macro
    int imaxsize = mesh_size*two_to_the(max_lev);

    int lev = level[ic];
    int ii = i[ic];
    int jj = j[ic];

    int imult = two_to_the(max_lev - lev);

    int iimin =  ii   *imult;
    int iimax = (ii+1)*imult;
    int jjmin =  jj   *imult;
    int jjmax = (jj+1)*imult;

    for (    int jjj = jjmin; jjj < jjmax; jjj++) {
        for (int iii = iimin; iii < iimax; iii++) {
            hashval(jjj, iii) = ic;
        }
    }
}

__kernel void full_perfect_hash_2part_setup1 (
                 const uint ncells,
                 const uint mesh_size,
                 const uint max_lev,
        __global const uint *i,
        __global const uint *j,
        __global const uint *level,
        __global       int  *hash){

    const int ic = get_global_id(0);

    if(ic >= ncells) return;

    // Needed for the stride in hashval macro
    int imaxsize = mesh_size*two_to_the(max_lev);

    int lev = level[ic];
    int ii = i[ic];
    int jj = j[ic];

    int imult = two_to_the(max_lev - lev);

    int iimin =  ii   *imult;
    int jjmin =  jj   *imult;
    
    hashval(jjmin, iimin) = ic;
}

__kernel void full_perfect_hash_2part_setup2 (
                 const uint ncells,
                 const uint mesh_size,
                 const uint max_lev,
        __global const uint *i,
        __global const uint *j,
        __global const uint *level,
        __global       int  *hash){

    const int ic = get_global_id(0);
    
    const int maxcellsize = two_to_the(max_lev);
    
    const int imaxsize = mesh_size*maxcellsize;
    
    if (ic>imaxsize*imaxsize) return;
    
    
    int jj = ic/imaxsize;
    int ii = ic%imaxsize;
    
    // these are the ij of the cell as if rounded to the largest possible cell
    // that could contain it
    int jb = (jj/maxcellsize)*maxcellsize;
    int ib = (ii/maxcellsize)*maxcellsize;
    
    int basekey = jb*imaxsize + ib;
    
    if (basekey == ic) return;
    
    if (level[hash[basekey]] == 0){
            hash[ic] = hash[basekey];
            return;
    }
    
    
    
    for (int lev = 0; lev < max_lev; lev++){
        // we need to know which quadrant to check next.
        int imult = two_to_the(max_lev-lev);
        
        
        
        // jr and ir together forming the far corner of a bounding box of base
        int jr = jb+imult;
        int ir = ib+imult;
        
        if (jr <= jj){
            jb+=imult;
        }
        if (ir <= ii){
            ib+=imult;
        }
        basekey = jb*imaxsize + ib;
        if (basekey == ic) return;
        // if we have the correct level, we look to write
        if (level[hash[basekey]] == lev){
            hash[ic] = hash[basekey];
            return;
        }
        //hash[ic] = ib;
    }
}

inline double avg_sub_cells (
                 uint   ji,
                 uint   ii,
                 uint   level,
                 uint   max_lev,
                 uint   mesh_size,
        __global const uint   *icells_level,
        __global const double *icellsVal,
        __global const int    *hash) {

    double sum = 0.0;
    uint i_max = two_to_the(max_lev);
    uint jump = two_to_the(max_lev - level - 1);

    // Needed for the stride in hashval macro
    int imaxsize = mesh_size*two_to_the(max_lev);

    for (int j = 0; j < 2; j++) {
        for (int i = 0; i < 2; i++) {
            int ic = hashval(ji + (j*jump), ii + (i*jump));
            if (icells_level[ic] == (level + 1)) {
                sum += icellsVal[ic];
            } else {
                sum += avg_sub_cells(ji + (j*jump), ii + (i*jump), level + 1,
                       max_lev, mesh_size, icells_level, icellsVal, hash);
            }
        }
    }

    return sum/4.0;
}

__kernel void full_perfect_hash_query (
                 const uint   ncells,
                 const uint   mesh_size,
                 const uint   max_lev,
        __global const int    *hash,
        __global const uint   *icells_level,
        __global const double *icells_values,
        __global const uint   *ocells_i,
        __global const uint   *ocells_j,
        __global const uint   *ocells_level,
        __global       double *ocells_values){

    const int i = get_global_id(0);

    if(i >= ncells) return;

    // Needed for the stride in hashval macro
    int imaxsize = mesh_size*two_to_the(max_lev);

    uint io = ocells_i[i];
    uint jo = ocells_j[i];
    uint lev = ocells_level[i];

    uint ii, ji;
    uint lev_mod = two_to_the(max_lev - lev);
    ii = io*lev_mod;
    ji = jo*lev_mod;

    int ic = hashval(ji, ii);

    if (lev > max_lev) lev = max_lev;
    while (ic < 0 && lev > 0) {
        lev--;
        uint lev_diff = max_lev - lev;
        ii >>= lev_diff;
        ii <<= lev_diff;
        ji >>= lev_diff;
        ji <<= lev_diff;
        ic = hashval(ji, ii);
    }
    if (lev >= icells_level[ic]) {
        ocells_values[i] = icells_values[ic];
    } else {
        ocells_values[i] = avg_sub_cells(ji, ii, lev, max_lev, mesh_size,
                           icells_level, icells_values, hash);
    }
}

__kernel void singlewrite_hash_init (
                 const uint hash_size,
        __global       int  *hash)
{
    const uint ic = get_global_id(0);

    if (ic >= hash_size) return;

    hash[ic] = -1;
}

__kernel void singlewrite_hash_setup (
                 const uint ncells,
                 const uint mesh_size,
                 const uint max_lev,
        __global const uint *i,
        __global const uint *j,
        __global const uint *level,
        __global       int  *hash){

    const int ic = get_global_id(0);

    if(ic >= ncells) return;

    // Needed for the stride in hashval macro
    int imaxsize = mesh_size*two_to_the(max_lev);

    int imult = two_to_the(max_lev - level[ic]);
    int iii =  i[ic]*imult;
    int jjj =  j[ic]*imult;

    hashval(jjj, iii) = ic;
}

__kernel void singlewrite_hash_query (
                 const uint   ncells,
                 const uint   mesh_size,
                 const uint   max_lev,
        __global const int    *hash,
        __global const uint   *icells_level,
        __global const double *icells_values,
        __global const uint   *ocells_i,
        __global const uint   *ocells_j,
        __global const uint   *ocells_level,
        __global       double *ocells_values){

    const int i = get_global_id(0);

    if(i >= ncells) return;

    // Needed for the stride in hashval macro
    int imaxsize = mesh_size*two_to_the(max_lev);

    uint io = ocells_i[i];
    uint jo = ocells_j[i];
    uint lev = ocells_level[i];

    uint lev_mod = two_to_the(max_lev - lev);
    uint ii = io*lev_mod;
    uint ji = jo*lev_mod;

    int ic = hashval(ji, ii);

    if (lev > max_lev) lev = max_lev;
    while (ic < 0 && lev > 0) {
        lev--;
        uint lev_diff = max_lev - lev;
        ii >>= lev_diff;
        ii <<= lev_diff;
        ji >>= lev_diff;
        ji <<= lev_diff;
        ic = hashval(ji, ii);
    }
    if (lev >= icells_level[ic]) {
        ocells_values[i] = icells_values[ic];
    } else {
        ocells_values[i] = avg_sub_cells(ji, ii, lev, max_lev, mesh_size,
                           icells_level, icells_values, hash);
    }
}

__kernel void compact_singlewrite_hash_setup (
                 const uint  ncells,
                 const uint  mesh_size,
                 const uint  max_lev,
        __global const uint  *i,
        __global const uint  *j,
        __global const uint  *level,
        __global const ulong *hash_header,
        __global       int   *hash){

    const int ic = get_global_id(0);

    if(ic >= ncells) return;

    // Needed for the stride in hashval macro
    int imaxsize = mesh_size*two_to_the(max_lev);

    const int hash_method       = (int)hash_header[0];
    const ulong hash_table_size =      hash_header[1];
    const ulong AA              =      hash_header[2];
    const ulong BB              =      hash_header[3];

    int imult = two_to_the(max_lev - level[ic]);
    int iii =  i[ic]*imult;
    int jjj =  j[ic]*imult;

    write_hash(hash_method, hash_table_size, AA, BB, ic, jjj*imaxsize+iii, hash);
}

inline double avg_sub_cells_compact (
                 uint   ji,
                 uint   ii,
                 uint   level,
                 uint   max_lev,
                 uint   mesh_size,
        __global const uint   *icells_level,
        __global const double *icellsVal,
        __global const ulong  *hash_header,
        __global const int    *hash) {

    double sum = 0.0;
    uint i_max = two_to_the(max_lev);
    uint jump = two_to_the(max_lev - level - 1);

    const int hash_method       = (int)hash_header[0];
    const ulong hash_table_size =      hash_header[1];
    const ulong AA              =      hash_header[2];
    const ulong BB              =      hash_header[3];

    // Needed for the stride in hashval macro
    int imaxsize = mesh_size*two_to_the(max_lev);

    for (int j = 0; j < 2; j++) {
        for (int i = 0; i < 2; i++) {
            int ic = read_hash(hash_method, hash_table_size, AA, BB, (ji + (j*jump))*imaxsize +(ii + (i*jump)), hash);
            if (icells_level[ic] == (level + 1)) {
                sum += icellsVal[ic];
            } else {
                sum += avg_sub_cells_compact(ji + (j*jump), ii + (i*jump), level + 1,
                       max_lev, mesh_size, icells_level, icellsVal, hash_header, hash);
            }
        }
    }

    return sum/4.0;
}

__kernel void compact_singlewrite_hash_query (
                 const uint   ncells,
                 const uint   mesh_size,
                 const uint   max_lev,
        __global const ulong  *hash_header,
        __global const int    *hash,
        __global const uint   *icells_level,
        __global const double *icells_values,
        __global const uint   *ocells_i,
        __global const uint   *ocells_j,
        __global const uint   *ocells_level,
        __global       double *ocells_values){

    const int i = get_global_id(0);

    if(i >= ncells) return;

    // Needed for the stride in hashval macro
    int imaxsize = mesh_size*two_to_the(max_lev);

    const int hash_method       = (int)hash_header[0];
    const ulong hash_table_size =      hash_header[1];
    const ulong AA              =      hash_header[2];
    const ulong BB              =      hash_header[3];

    uint io = ocells_i[i];
    uint jo = ocells_j[i];
    uint lev = ocells_level[i];

    uint lev_mod = two_to_the(max_lev - lev);
    uint ii = io*lev_mod;
    uint ji = jo*lev_mod;

    int ic = read_hash(hash_method, hash_table_size, AA, BB, ji*imaxsize+ii, hash);

    if (lev > max_lev) lev = max_lev;
    while (ic < 0 && lev > 0) {
        lev--;
        uint lev_diff = max_lev - lev;
        ii >>= lev_diff;
        ii <<= lev_diff;
        ji >>= lev_diff;
        ji <<= lev_diff;
        ic = read_hash(hash_method, hash_table_size, AA, BB, ji*imaxsize+ii, hash);
    }
    if (lev >= icells_level[ic]) {
        ocells_values[i] = icells_values[ic];
    } else {
        ocells_values[i] = avg_sub_cells_compact(ji, ii, lev, max_lev, mesh_size,
                           icells_level, icells_values, hash_header, hash);
    }
}

__kernel void hierarchical_cell_insert (
        __global uint* hhash,
        __constant uint* hash_memory_indices,
        __constant uint* celli,
        __constant uint* cellj,
        __constant uint* cellLev,
        __const uint ncells,
        __const uint mesh_size){

    uint idx = get_global_id(0);

    if (idx >= ncells) return;

    uint lev = cellLev[idx];
    uint i = celli[idx];
    uint j = cellj[idx];

    uint key = j * mesh_size*two_to_the(lev) + i;
    hhash[hash_memory_indices[lev]+key] = idx;

    // the lower left corner leaves a marker above for the 4 cells
    while (i%2 == 0 && j%2 == 0 && lev>0){
        i/=2;
        j/=2;
        lev--;
        key = j * mesh_size*two_to_the(lev) + i;
        hhash[hash_memory_indices[lev]+key] = -1;
    }
}

inline uint translate_cell (uint i, uint j, uint lev, uint newLev) {
    uint newKey;
    uint ycomp, xcomp;

    // moving finer/coarser levels
    ycomp = j * two_to_the(newLev - lev);
    xcomp = i * two_to_the(newLev - lev);

    newKey = (ycomp * two_to_the(newLev)) + xcomp;
    return newKey;
}


inline double avg_sub_cells_h (__constant double* icellsVal, uint i, uint j, uint lev,
      __const uint mesh_size, __constant uint *hhash, __constant uint* hash_memory_indices) {

    int probe;
    double sum = 0.0;
    
    uint key_new[4];
    
    int startlev = lev;
    
    char queue[32];

    queue[startlev+1] = 0;
    
    lev++;
    i *= 2;
    j *= 2;
    
    // The premise of this loop is that we descend to finer levels of the mesh,
    // for each of which we loop through the square of four hash values that
    // were below our previous position in the hash hierarchy. The 'queue'
    // tracks where our probe was on the previous levels, allowing us to return
    // to the levels above and continue once we have completed averaging the
    // sub-cells of a flagged hash value.
    while (lev > startlev) {
    
        // Make sure that when returning from a finer level we are on even
        // numbered coordinates, so that we maintain the same reference for the
        // queue.
        i-=i%2;
        j-=j%2;
    
        // If the final hash value read at a level was a sentinal value, the 
        // queue at that level will be set to 4 before moving down to the finer
        // level of the hash. In those cases, when we return we should move up
        // another level immediately.
        if (queue[lev]>3){
                lev--;
                i/=2;
                j/=2;
                continue;
        }
        
        uint istride = mesh_size*two_to_the(lev);
        uint key = j*istride + i;
        

        key_new[0] = key;
        key_new[1] = key + 1;
        key_new[2] = key + istride;
        key_new[3] = key + istride + 1;
        
        
        
        for (int ic = queue[lev]; ic < 4; ic++){
            
            key = key_new[ic];
            
            probe = hhash[hash_memory_indices[lev]+key];
            if (probe >= 0) {
                //TODO: try to move this division so we have fewer computations
                sum += icellsVal[probe]/four_to_the(lev-startlev);
            } else {
                // When the sentinal value is set, setup the queue for our
                // return and move down a level.
                queue[lev] = ic+1;
                i = key % istride;
                j = key / istride;
                lev++;
                i *= 2;
                j *= 2;
                // Setup the next level to begin at the right point
                queue[lev] = 0;
                break;
            }
            if (ic==3){
                lev--;
                i/=2;
                j/=2;
            }
        }
    }

    return sum;
}

__kernel void hierarchical_hash_probe (__constant uint* hhash,
            __constant uint* hash_memory_indices,
            __constant uint* celli,
            __constant uint* cellj,
            __constant uint* cellLev,
            __constant double* icellVal,
            __global double* ocellVal,
            __const uint ncells,
            __const uint mesh_size){

    uint idx = get_global_id(0);

    if (idx >= ncells) return;

    uint oi = celli[idx];
    uint oj = cellj[idx];
    uint olev = cellLev[idx];

#ifdef XXX
    // if the olev is already coarser than the finest input cell, we know it will have to be an average

    if (olev < 0){
        // the olev is incremented one because the top level of the average is one level finer
       //  than the output cell, and i,j also have to be adjusted
        ocellVal [idx] = avg_sub_cells_h (icellVal, oi, oj, olev, mesh_size, hhash, hash_memory_indices);
    }
#endif

    int probe = -1;
    // loop until either we find a valid hash value or the probelev is the output cell level
    for (uint probeLev = 0; probe == -1 && probeLev <= olev; probeLev++) {
        //uint key = translate_cell(oi,oj,olev,probeLev);
        int levdiff = olev-probeLev;
        uint key = (oj >> levdiff)*mesh_size*two_to_the(probeLev) + (oi >> levdiff);
        probe = hhash[hash_memory_indices[probeLev]+key];
    }

    if (probe != -1){
        ocellVal[idx] = icellVal[probe];
    }else{
        // the olev is incremented one because the top level of the average is one level finer
        // than the output cell, and i,j also have to be adjusted
        ocellVal [idx] = avg_sub_cells_h (icellVal, oi, oj, olev, mesh_size, hhash, hash_memory_indices);
    }
}

void reduction_sum_uintlev_within_tile(__local  uint  *tile, uint levmax);

#define tilelev(tix, lev)  tile[(tix)*(levmax+1) + (lev)]
#define scratchlev(tix, lev)  scratch[(tix)*(levmax+1) + (lev)]

//#define tilelev(tix, lev)  tile[(lev)*ntX + (tix)]
//#define scratchlev(tix, lev)  scratch[(lev)*ntX + (tix)]

__kernel void hierarchical_count_levels_stage1of2(
                 const uint  isize,        // 0  Total number of cells.
                 const uint  levmax,       // 1
        __global const uint *levels,       // 2
        __global       uint *num_at_level, // 3
        __global       uint *scratch,      // 4
        __local        uint *tile)         // 5
{
    const unsigned int giX  = get_global_id(0);
    const unsigned int tiX  = get_local_id(0);

    const unsigned int group_id = get_group_id(0);

    for (int il = 0; il <= levmax; il++){
       tilelev(tiX,il) = 0;
    }
    if (giX < isize) {
        uint lev = levels[giX];
        tilelev(tiX,lev) = 1;
    }

    barrier(CLK_LOCAL_MEM_FENCE);

    reduction_sum_uintlev_within_tile(tile,levmax);

    //  Write the local value back to an array size of the number of groups
    if (tiX == 0){
       for (int il = 0; il <= levmax; il++){
          scratchlev(group_id,il) = tilelev(0,il);
          num_at_level[il] = tilelev(0,il);
       }
    }
}

__kernel void hierarchical_count_levels_stage2of2(
                 const uint  isize,        // 0  Total number of cells.
                 const uint  levmax,       // 1
        __global       uint *num_at_level, // 2
        __global       uint *scratch,      // 3
        __local        uint *tile)         // 4
{
    const unsigned int tiX  = get_local_id(0);
    const unsigned int ntX  = get_local_size(0);

    uint giX = tiX;

    for (int il = 0; il <= levmax; il++){
       tilelev(tiX,il) = 0;
    }

    if (tiX < isize) {
       for (int il = 0; il <= levmax; il++){
          tilelev(tiX,il) = scratchlev(giX,il);
       }
    }

    for (giX += ntX; giX < isize; giX += ntX) {
       for (int il = 0; il <= levmax; il++){
          tilelev(tiX,il) += scratchlev(giX,il);
       }
    }

    barrier(CLK_LOCAL_MEM_FENCE);

    reduction_sum_uintlev_within_tile(tile, levmax);

    if (tiX == 0) {
       for (int il = 0; il <= levmax; il++){
          num_at_level[il] = tilelev(0, il);
       }
    }
}

void reduction_sum_uintlev_within_tile(__local  uint  *tile, uint levmax)
{
   const unsigned int tiX  = get_local_id(0);
   const unsigned int ntX  = get_local_size(0);

     for (int lev = 0; lev <= levmax; lev++){
        for (int offset=ntX>>1; offset > 32; offset >>= 1){
           if (tiX < offset){
              tilelev(tiX,lev) += tilelev(tiX+offset,lev);
           }
           barrier(CLK_LOCAL_MEM_FENCE);
        }

        if (tiX < 32) {
           tilelev(tiX,lev) += tilelev(tiX+32,lev);
           tilelev(tiX,lev) += tilelev(tiX+16,lev);
           tilelev(tiX,lev) += tilelev(tiX+8,lev);
           tilelev(tiX,lev) += tilelev(tiX+4,lev);
           tilelev(tiX,lev) += tilelev(tiX+2,lev);
           tilelev(tiX,lev) += tilelev(tiX+1,lev);
        }
    }

}

__kernel void hierarchical_compact_insert(
                 const uint  ncells,       // 0  Total number of cells.
                 const uint  ibasesize,
        __global const uint *icells_i,
        __global const uint *icells_j,
        __global const uint *icells_level,
        __global       char  *h_hashTable0,
        __global       char  *h_hashTable1,
        __global       char  *h_hashTable2,
        __global       char  *h_hashTable3,
        __global       char  *h_hashTable4,
        __global       char  *h_hashTable5,
        __global       char  *h_hashTable6,
        __global       char  *h_hashTable7,
        __global       char  *h_hashTable8,
        __global       char  *h_hashTable9,
        __global       char  *h_hashTable10)
{
    uint idx = get_global_id(0);

    if (idx >= ncells) return;

    //place the cells and their breadcrumbs 
    uint i = icells_i[idx];
    uint j = icells_j[idx];
    int lev = icells_level[idx];

    uint key = j * ibasesize*two_to_the(lev) + i;
    __global char *hashtable = h_hashTable0;
    switch (lev) {
    case 0:
       hashtable = h_hashTable0;
       break;
    case 1:
       hashtable = h_hashTable1;
       break;
    case 2:
       hashtable = h_hashTable2;
       break;
    case 3:
       hashtable = h_hashTable3;
       break;
    case 4:
       hashtable = h_hashTable4;
       break;
    case 5:
       hashtable = h_hashTable5;
       break;
    case 6:
       hashtable = h_hashTable6;
       break;
    case 7:
       hashtable = h_hashTable7;
       break;
    case 8:
       hashtable = h_hashTable8;
       break;
    case 9:
       hashtable = h_hashTable9;
       break;
    case 10:
       hashtable = h_hashTable10;
       break;
    }
    intintHash_InsertSingle(hashtable, key, idx);

    while (i%2 == 0 && j%2 == 0 && lev > 0) {
        i /= 2;
        j /= 2;
        lev--;
        switch (lev) {
        case 0:
           hashtable = h_hashTable0;
           break;
        case 1:
           hashtable = h_hashTable1;
           break;
        case 2:
           hashtable = h_hashTable2;
           break;
        case 3:
           hashtable = h_hashTable3;
           break;
        case 4:
           hashtable = h_hashTable4;
           break;
        case 5:
           hashtable = h_hashTable5;
           break;
        case 6:
           hashtable = h_hashTable6;
           break;
        case 7:
           hashtable = h_hashTable7;
           break;
        case 8:
           hashtable = h_hashTable8;
           break;
        case 9:
           hashtable = h_hashTable9;
           break;
        case 10:
           hashtable = h_hashTable10;
           break;
        }
        key = j * ibasesize*two_to_the(lev) + i;
        intintHash_InsertSingle(hashtable, key, -1);
    }
}

double avg_sub_cells_h_compact(__global const double *icells_values, uint i, uint j, uint lev, uint ibasesize, __global int *ierr,
        __global       char   *h_hashTable0,
        __global       char   *h_hashTable1,
        __global       char   *h_hashTable2,
        __global       char   *h_hashTable3,
        __global       char   *h_hashTable4,
        __global       char   *h_hashTable5,
        __global       char   *h_hashTable6,
        __global       char   *h_hashTable7,
        __global       char   *h_hashTable8)
{
   __global char *hashtable = h_hashTable0;
   
   
    uint gidx = get_global_id(0);

    double sum = 0.0;
    
    uint key_new[4];
    
    int startlev = lev;
    
    char queue[32];

    queue[startlev+1] = 0;
    
    lev++;
    i *= 2;
    j *= 2;
    
    // The premise of this loop is that we descend to finer levels of the mesh,
    // for each of which we loop through the square of four hash values that
    // were below our previous position in the hash hierarchy. The 'queue'
    // tracks where our probe was on the previous levels, allowing us to return
    // to the levels above and continue once we have completed averaging the
    // sub-cells of a flagged hash value.
    while (lev > startlev) {
    
        
        
        // Make sure that when returning from a finer level we are on even
        // numbered coordinates, so that we maintain the same reference for the
        // queue.
        i-=i%2;
        j-=j%2;
    
        // If the final hash value read at a level was a sentinal value, the 
        // queue at that level will be set to 4 before moving down to the finer
        // level of the hash. In those cases, when we return we should move up
        // another level immediately.
        if (queue[lev]>3){
                lev--;
                i/=2;
                j/=2;
                continue;
        }
        
        switch (lev) {
        case 0:
            hashtable = h_hashTable0;
            break;
        case 1:
            hashtable = h_hashTable1;
            break;
        case 2:
            hashtable = h_hashTable2;
            break;
        case 3:
            hashtable = h_hashTable3;
            break;
        case 4:
            hashtable = h_hashTable4;
            break;
        case 5:
            hashtable = h_hashTable5;
            break;
        case 6:
            hashtable = h_hashTable6;
            break;
        case 7:
            hashtable = h_hashTable7;
            break;
        case 8:
            hashtable = h_hashTable8;
            break;
        }
        
        uint istride = ibasesize*two_to_the(lev);
        uint key = j*istride + i;
        

        key_new[0] = key;
        key_new[1] = key + 1;
        key_new[2] = key + istride;
        key_new[3] = key + istride + 1;
        
        
        
        for (int ic = queue[lev]; ic < 4; ic++){
            
            key = key_new[ic];
            
            intintHash_QuerySingle(hashtable, key, &ierr[gidx]);
            if (ierr[gidx] >= 0) {
                //TODO: try to move this division so we have fewer computations
                sum += icells_values[ierr[gidx]]/four_to_the(lev-startlev);
            } else {
                // When the sentinal value is set, setup the queue for our
                // return and move down a level.
                queue[lev] = ic+1;
                i = key % istride;
                j = key / istride;
                lev++;
                i *= 2;
                j *= 2;
                // Setup the next level to begin at the right point
                queue[lev] = 0;
                break;
            }
            if (ic==3){
                lev--;
                i/=2;
                j/=2;
            }
        }
    }

    return sum;
}

__kernel void hierarchical_compact_probe(
                 const uint    ncells,       // 0  Total number of cells.
                 const uint    ibasesize,
        __global const uint   *ocells_i,
        __global const uint   *ocells_j,
        __global const uint   *ocells_level,
        __global const double *icells_values,
        __global       double *ocells_values,
        __global       char   *h_hashTable0,
        __global       char   *h_hashTable1,
        __global       char   *h_hashTable2,
        __global       char   *h_hashTable3,
        __global       char   *h_hashTable4,
        __global       char   *h_hashTable5,
        __global       char   *h_hashTable6,
        __global       char   *h_hashTable7,
        __global       char   *h_hashTable8,
        __global       int    *ierr)
{
    uint idx = get_global_id(0);

    if (idx >= ncells) return;

    uint oi = ocells_i[idx];
    uint oj = ocells_j[idx];
    uint olev = ocells_level[idx];

    __global char *hashtable = h_hashTable0;
    
    ierr[idx] = -1;

    for (uint probe_lev = 0; ierr[idx] < 0 && probe_lev <= olev; probe_lev++){
        switch (probe_lev) {
        case 0:
           hashtable = h_hashTable0;
           break;
        case 1:
           hashtable = h_hashTable1;
           break;
        case 2:
           hashtable = h_hashTable2;
           break;
        case 3:
           hashtable = h_hashTable3;
           break; 
        case 4:
           hashtable = h_hashTable4;
           break;
        case 5:
           hashtable = h_hashTable5;
           break;
        case 6:
           hashtable = h_hashTable6;
           break;
        case 7:
           hashtable = h_hashTable7;
           break;
        case 8:
           hashtable = h_hashTable8;
           break;
        }
        int levdiff = olev - probe_lev;
        uint key = (oj >> levdiff)*ibasesize*two_to_the(probe_lev) + (oi >> levdiff);
        intintHash_QuerySingle(hashtable, key, &ierr[idx]);
    }
        
    
    if (ierr[idx] >= 0) {
        ocells_values[idx] = icells_values[ierr[idx]];
    } else {
        ocells_values[idx] = avg_sub_cells_h_compact (icells_values, oi, oj, olev, ibasesize, ierr,
            h_hashTable0, h_hashTable1, h_hashTable2, h_hashTable3, h_hashTable4, h_hashTable5,
            h_hashTable6, h_hashTable7, h_hashTable8);
    }
}

