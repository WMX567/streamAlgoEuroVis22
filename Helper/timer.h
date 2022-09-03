/*
 * timer.h
 */

#ifndef TIMER_H
#define TIMER_H

#define SYS5 

/*
 * Public functions
 */
void   TimerStart(int);
void   TimerStop(int);
double TimerGetUTime(int);
double TimerGetSTime(int);
double TimerGetRTime(int);

#endif   /* TIMER_H */
