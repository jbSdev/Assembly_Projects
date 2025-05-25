#include <stdio.h>
#include <stdlib.h>
int find_markers(unsigned char* bitmap,
                 unsigned int *x_pos,
                 unsigned int *y_pos);

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

    unsigned int x_pos[50];
    unsigned int y_pos[50];
    unsigned int output;
    output = find_markers(bitmap, x_pos, y_pos);

    printf("Output value: %d\n", output);

    free(bitmap);
    return 0;
}
