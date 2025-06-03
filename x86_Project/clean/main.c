#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

unsigned int find_markers(unsigned char* bitmap,
                 unsigned int* x_pos,
                 unsigned int* y_pos);

unsigned int x_pos[50], y_pos[50];
unsigned int output;
int i = 0;

void readBMP(char* buffer, FILE* fstream)
{
    while (!feof(fstream))
        buffer[i++] = fgetc(fstream);
}

int main()
{
    char filename[50];
    printf("Please input the filename: ");
    fflush(stdout);
    scanf("%s", filename);
    
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

    output = find_markers(bitmap, x_pos, y_pos);

    printf("Output value: %u\n", output);
    i = -1;
    while (x_pos[++i] != -1 && i != 50)
        printf("%u\t%u\n", x_pos[i], y_pos[i]);

    free(bitmap);
    return 0;
}
