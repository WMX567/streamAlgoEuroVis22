/*
 * timer.h
 *
 * Codes taken from Unix Network Programming by Richard Stevens
 *
 * Timer routines.
 *
 * These routines are structured so that there are only the following
 * entry points:
 *
 *	void	TimerStart()	start timer
 *	void	TimerStop()	stop timer
 *	double	TimerGetRTime()	return real (elapsed) time (seconds)
 *	double	TimerGetUTime()	return user time (seconds)
 *	double	TimerGetSTime()	return system time (seconds)
 *
 * Purposely, there are no structures passed back and forth between
 * the caller and these routines, and there are no include files
 * required by the caller.
 */

/* #define BSD */
/* printf, fopen */
#include    <stdlib.h>
#include	<stdio.h>
#include	"timer.h"

#ifdef BSD
#include	<sys/time.h>
#include	<sys/resource.h>
#endif

#ifdef SYS5
#include	<sys/types.h>
#include	<sys/times.h>
#include	<sys/param.h>	/* need the definition of HZ */
#define		TICKS	HZ	/* see times(2); usually 60 or 100 */
#endif

#ifdef BSD
static	struct timeval		time_start[32], time_stop[32];/*  real time */
static	struct rusage		ru_start[32], ru_stop[32]; /* user & sys time */
#endif

#ifdef SYS5
static	long			time_start[32], time_stop[32];
static	struct tms		tms_start[32], tms_stop[32];
long				times();
#endif

static	double			start, stop, seconds;

#define err_sys(x) { fprintf(stderr, "pvr: (timer) %s\n", x); exit(1); }

/*
 * Start the timer.
 * We don't return anything to the caller, we just store some
 * information for the stop timer routine to access.
 */
void
TimerStart(int k)
{

#ifdef BSD
	if (gettimeofday(time_start+k, (struct timezone *) 0) < 0)
		err_sys("TimerStart: gettimeofday() error");
	if (getrusage(RUSAGE_SELF, ru_start+k) < 0)
		err_sys("TimerStart: getrusage() error");
#endif

#ifdef SYS5
	if ( (time_start[k] = times(tms_start+k)) == -1)
		err_sys("TimerStart: times() error");
#endif

}

/*
 * Stop the timer and save the appropriate information.
 */
void
TimerStop(int k)
{

#ifdef BSD
	if (getrusage(RUSAGE_SELF, ru_stop+k) < 0)
		err_sys("TimerStop: getrusage() error");
	if (gettimeofday(time_stop+k, (struct timezone *) 0) < 0)
		err_sys("TimerStop: gettimeofday() error");
#endif

#ifdef SYS5
	if ( (time_stop[k] = times(tms_stop+k)) == -1)
		err_sys("TimerStop: times() error");
#endif

}

/*
 * Return the user time in seconds.
 */
double
TimerGetUTime(int k)
{

#ifdef BSD
	start = ((double) ru_start[k].ru_utime.tv_sec) * 1000000.0
				+ ru_start[k].ru_utime.tv_usec;
	stop = ((double) ru_stop[k].ru_utime.tv_sec) * 1000000.0
				+ ru_stop[k].ru_utime.tv_usec;
	seconds = (stop - start) / 1000000.0;
#endif

#ifdef SYS5
	seconds = (double) (tms_stop[k].tms_utime - tms_start[k].tms_utime) /
					(double) TICKS;
#endif

	return(seconds);
}

/*
 * Return the system time in seconds.
 */
double
TimerGetSTime(int k)
{

#ifdef BSD
	start = ((double) ru_start[k].ru_stime.tv_sec) * 1000000.0
				+ ru_start[k].ru_stime.tv_usec;
	stop = ((double) ru_stop[k].ru_stime.tv_sec) * 1000000.0
				+ ru_stop[k].ru_stime.tv_usec;
	seconds = (stop - start) / 1000000.0;
#endif

#ifdef SYS5
	seconds = (double) (tms_stop[k].tms_stime - tms_start[k].tms_stime) /
					(double) TICKS;
#endif

	return(seconds);
}

/*
 * Return the real (elapsed) time in seconds.
 */
double
TimerGetRTime(int k)
{

#ifdef BSD
	start = ((double) time_start[k].tv_sec) * 1000000.0
				+ time_start[k].tv_usec;
	stop = ((double) time_stop[k].tv_sec) * 1000000.0
				+ time_stop[k].tv_usec;
	seconds = (stop - start) / 1000000.0;
#endif

#ifdef SYS5
	seconds = (double) (time_stop[k] - time_start[k]) / (double) TICKS;
#endif

	return(seconds);
}


/* end of timer.c */
