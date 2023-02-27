/*
 * This is the source of the libraries stored in binary form in the i386 and sun4v
 * directories and is required to be able to run Liberica JDK11 on Solaris 10.
 * See https://github.com/adoptium/infrastructure/issues/2763#issuecomment-1338305341
 */
#include <stdio.h>
int posix_fallocate(int fd, off_t offset, off_t len)
{
  fprintf(stderr, "posix_fallocate() called but stubbed out\n");
}

