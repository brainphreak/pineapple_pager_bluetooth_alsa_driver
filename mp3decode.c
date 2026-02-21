/*
 * mp3decode - Tiny MP3-to-PCM decoder for WiFi Pineapple Pager
 *
 * Decodes MP3 to raw S16LE PCM on stdout for piping to aplay.
 * Uses minimp3 (single-header, no dependencies).
 *
 * Usage:
 *   ./mp3decode song.mp3 | aplay -D bluealsa -f S16_LE -r 44100 -c 2 -
 *   cat song.mp3 | ./mp3decode - | aplay -D bluealsa -f S16_LE -r 44100 -c 2 -
 *
 * Prints "INFO: <rate> Hz, <channels> channels" to stderr on first frame.
 */

#define MINIMP3_IMPLEMENTATION
#define MINIMP3_ONLY_MP3
#define MINIMP3_NO_SIMD
#include "minimp3.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define READ_BUF_SIZE  (16 * 1024)
#define MAX_BUF_SIZE   (2 * 1024 * 1024)

int main(int argc, char *argv[])
{
    FILE *fp;
    mp3dec_t dec;
    mp3dec_frame_info_t info;
    mp3d_sample_t pcm[MINIMP3_MAX_SAMPLES_PER_FRAME];
    unsigned char *buf = NULL;
    size_t buf_size = 0, buf_filled = 0, buf_consumed = 0;
    int first_frame = 1;
    int samples;
    size_t nr;

    if (argc < 2) {
        fprintf(stderr, "Usage: %s <file.mp3 | ->\n", argv[0]);
        return 1;
    }

    if (strcmp(argv[1], "-") == 0) {
        fp = stdin;
    } else {
        fp = fopen(argv[1], "rb");
        if (!fp) {
            fprintf(stderr, "ERROR: Cannot open %s\n", argv[1]);
            return 1;
        }
    }

    mp3dec_init(&dec);

    buf_size = READ_BUF_SIZE;
    buf = (unsigned char *)malloc(buf_size);
    if (!buf) {
        fprintf(stderr, "ERROR: Out of memory\n");
        return 1;
    }

    for (;;) {
        /* Shift unconsumed data to front */
        if (buf_consumed > 0) {
            buf_filled -= buf_consumed;
            if (buf_filled > 0)
                memmove(buf, buf + buf_consumed, buf_filled);
            buf_consumed = 0;
        }

        /* Read more data if buffer has room */
        if (buf_filled < buf_size) {
            nr = fread(buf + buf_filled, 1, buf_size - buf_filled, fp);
            buf_filled += nr;
        }

        if (buf_filled == 0)
            break;

        /* Decode one frame */
        samples = mp3dec_decode_frame(&dec, buf, (int)buf_filled, pcm, &info);
        if (info.frame_bytes == 0) {
            /* No sync found — need more data or EOF */
            if (feof(fp))
                break;
            /* Grow buffer to find sync */
            if (buf_size < MAX_BUF_SIZE) {
                buf_size *= 2;
                buf = (unsigned char *)realloc(buf, buf_size);
                if (!buf) {
                    fprintf(stderr, "ERROR: Out of memory\n");
                    return 1;
                }
            }
            continue;
        }

        buf_consumed = (size_t)info.frame_bytes;

        if (samples > 0) {
            if (first_frame) {
                fprintf(stderr, "INFO: %d Hz, %d channels\n",
                        info.hz, info.channels);
                first_frame = 0;
            }
            /* Write S16LE PCM to stdout */
            fwrite(pcm, sizeof(mp3d_sample_t),
                   (size_t)(samples * info.channels), stdout);
        }
    }

    free(buf);
    if (fp != stdin)
        fclose(fp);

    return 0;
}
