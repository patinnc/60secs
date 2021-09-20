#include <time.h>
#include <stdio.h>
#ifdef _WIN32
#include <intrin.h>
#pragma intrinsic(__rdtsc)
#pragma intrinsic(__rdtscp)
#else
#define _GNU_SOURCE             /* See feature_test_macros(7) */
#include <unistd.h>
#include <sys/syscall.h>   /* For SYS_xxx definitions */
#ifdef __x86_64__
#include <x86intrin.h>
#endif
#endif
#include <inttypes.h>
#include <stdint.h>

static unsigned int my_getcpu(void)
{
        unsigned int cpu=0;
#ifdef __x86_64__
        __rdtscp(&cpu);
#elif __aarch64__
        unsigned int nd=0;
        int rc;
        rc =  syscall (__NR_getcpu, &cpu, &nd);
#endif
        return cpu;
}

#if __aarch64__
static uint64_t get_arm_cyc(void)
{
  uint64_t tsc;
  // this isn't really a TSC. Just some counter. I don't yet know how if it stops when the cpu is stopped. Or if it chgs freq.
  asm volatile("mrs %0, cntvct_el0" : "=r" (tsc));
  //asm volatile("mrs %0, pmcr_el0" : "=r" (tsc));
  return tsc;
}
#endif

static uint64_t get_tsc_and_cpu(unsigned int *cpu)
{
        uint64_t tsc=0;
#ifdef __x86_64__
        uint32_t aux, node;
        tsc = __rdtscp(&aux);
        node = ((aux >> 12) & 0xf);
        *cpu  = (aux & 0xfff);
#elif __aarch64__
        *cpu = my_getcpu();
	tsc  = get_arm_cyc();
#endif
        return tsc;
}

double dclock(void)
{
        struct timespec tp;
        clock_gettime(CLOCK_MONOTONIC, &tp);
        return (double)(tp.tv_sec) + 1.0e-9 * (double)(tp.tv_nsec);
}

#ifndef _WIN32 
//#define D1 " ror $2, %%eax;"
//#define D1 " movl $2, %%eax;"
#ifdef __x86_64__
#define D1 " rorl $2, %%eax;"
#elif __aarch64__
#define D1 "add     x0, x0, 1;"
#endif
//#define D1 " lea (%%eax),%%eax;"
//#define D1 " nop;"
//#define D1 " andl $1, %%eax;"
//#define D1 " rcll $1, %%eax;"
#define D10 D1 D1 D1 D1 D1  D1 D1 D1 D1 D1
#define D100 D10 D10 D10 D10 D10  D10 D10 D10 D10 D10
#define D1000 D100 D100 D100 D100 D100  D100 D100 D100 D100 D100
#define D10000 D1000 D1000 D1000 D1000 D1000  D1000 D1000 D1000 D1000 D1000
#define D100000 D10000 D10000 D10000 D10000 D10000  D10000 D10000 D10000 D10000 D10000
//#define D40000 D10000 D10000 D10000 D10000
//#define D1000000 D100000 D100000 D100000 D100000 D100000  D100000 D100000 D100000 D100000 D100000
#endif
   


int main(int argc, char **argv)
{
   unsigned int cpu, cpu0;
   int i, tries= 0;
   double tm_beg, tm_end, frq, ifrq;
   double ops=0, loops=0;
   uint64_t t1, t0;
   uint32_t a=43, b=67;
   int loops_inner=50;

   cpu = 0;
   cpu0 = 1;
   while(cpu != cpu0 && tries < 100) {
   cpu = my_getcpu();
   tm_beg = tm_end = dclock();
   t0 = get_tsc_and_cpu(&cpu);
   ops=0;
   loops=0;
   while(tm_end - tm_beg < 0.05) {
     for (i=0; i < loops_inner; i++) {
#ifdef _WIN32
           b = win_rorl(b); // 10000 inst
#else
#ifdef __x86_64__
           asm ( "movl %1, %%eax;"
              ".align 4;"
              D100000
              /*D100000*/
              " movl %%eax, %0;"
              :"=r"(b) /* output */
              :"r"(a)  /* input */
              :"%eax"  /* clobbered reg */
            );
#elif __aarch64__
            asm ( D100000 : : : "x0");
            //a += b;
#endif
#endif
            a |= b;
       ops += 100000;
       loops += 1;
     }
       tm_end = dclock();
   }
    t1 = get_tsc_and_cpu(&cpu0);
    if (cpu == cpu0) {break;}
    tries++;
   }
   frq = (double)(t1-t0)/(tm_end - tm_beg);
   ifrq = 1.0/frq;
   printf("tsc_freq= %.3f GHz, cpu_beg= %d, cpu_end= %d, tries= %d, tm_diff= %.6f secs, loops= %.0f\n", frq*1.0e-9, cpu, cpu0, tries, tm_end-tm_beg, loops);
   frq = (double)(ops)/(tm_end - tm_beg);
   printf("ops_freq= %.3f GHz\n", frq*1.0e-9);
   if (a == 47) {printf("got a= 47\n"); }

   return 0;
}

