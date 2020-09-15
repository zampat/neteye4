#include <stdio.h>
#include <stdlib.h>

main(int argc, char *argv[])
{
        int ret;

        ret=fork();
        if (ret == 0) {
        setuid(geteuid());
        execle("/bin/sh","sh","-c", "killall -USR1 automount >/dev/null 2>&1",0,0);
        }
}
