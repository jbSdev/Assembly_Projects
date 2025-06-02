#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

unsigned int find_markers(unsigned char* bitmap,
                 unsigned int* x_pos,
                 unsigned int* y_pos,
                 unsigned int* length,
                 unsigned int* width);

unsigned int x_pos[50], y_pos[50], length[50], width[50];
unsigned int output;
uint64_t s_cyc, e_cyc;
int i = 0;

// CPU cycles counter
static inline uint64_t read_tsc()
{
    uint32_t lo, hi;
    __asm__ __volatile__("rdtsc" : "=a"(lo), "=d"(hi));
    return ((uint64_t)hi << 32) | lo;
}

void readBMP(char* buffer, FILE* fstream)
{
    while (!feof(fstream))
        buffer[i++] = fgetc(fstream);
}

int main()
{
    //char filename[50];
    //printf("Please input the filename: ");
    //fflush(stdout);
    //scanf("%s", filename);
    
    //char* filename = "test.bmp";
    char* filename = "source.bmp";

    // open the file
    FILE* file = fopen(filename, "r");
    if (!file)
    {
        printf("Unable to open the file. Exiting\n");
        return -1;
    }

    // get the file size
    fseek(file, 0, SEEK_END);
    long filesize = ftell(file);
    fseek(file, 0, SEEK_SET);

    // allocate the buffer
    unsigned char* bitmap = malloc(filesize);
    if (!bitmap)
    {
        perror("Failed to allocate the bitmap space\n");
        fclose(file);
        return -2;
    }

    // read file into the buffer
    size_t read = fread(bitmap, 1, filesize, file);
    if (read != filesize)
    {
        perror("Failed to read the file\n");
        free(bitmap);
        fclose(file);
        return -3;
    }

    fclose(file);

    for (int i = 0; i < 50; i++)
        x_pos[i] = y_pos[i] = -1;

    s_cyc = read_tsc();
    output = find_markers(bitmap, x_pos, y_pos, length, width);
    e_cyc = read_tsc();

    printf("Output value: %u\n", output);
    i = -1;
    while (x_pos[++i] != -1 && i != 50)
        printf("%u\t%u\t%u\t%u\n", x_pos[i], y_pos[i], length[i], width[i]);

    printf("CPU Cycles: %llu\n", (unsigned long long)(e_cyc - s_cyc));

    free(bitmap);
    return 0;
}
