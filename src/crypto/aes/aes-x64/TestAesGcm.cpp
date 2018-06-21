#include <stdio.h>
#include <stdint.h>
#include <chrono>

typedef unsigned char byte;

struct args
{
    byte *plain_ptr;
    uint64_t plain_num_bytes;
    byte *auth_ptr;
    uint64_t auth_num_bytes;
    byte *iv_ptr;
    byte *expanded_key_ptr;
    byte *out_ptr;
    byte *tag_ptr;
};

extern "C" void aes128_key_expansion(byte *key_ptr, byte *key_expansion_ptr);
extern "C" void gcm128_encrypt(args *a);
extern "C" int gcm128_decrypt(args *a);

byte key[16] =
    { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
byte key_expansion[11 * 16];

byte plain[32] =
    { 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215,
      216, 217, 218, 99,  0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0
    };
byte auth[1]; // actually size 0
byte iv[16] =
    { 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 0, 0, 0, 0 };
byte out[32];
byte tag[16];

void printbytes(char *label, byte *b, int len)
{
    printf("%s:", label);
    for (int i = 0; i < len; i++) printf(" %2x", unsigned(b[i]));
    printf("\n");
}

int main()
{
    printf("hello\n");

    args a;
    a.plain_ptr = plain;
    a.plain_num_bytes = 19;
    a.auth_ptr = auth;
    a.auth_num_bytes = 0;
    a.iv_ptr = iv;
    a.expanded_key_ptr = key_expansion;
    a.out_ptr = out;
    a.tag_ptr = tag;
    printbytes("key", key, 16);
    aes128_key_expansion(key, key_expansion);
    printbytes("key_expansion", key_expansion, 11 * 16);
    gcm128_encrypt(&a);
    printbytes("cipher", out, 19);
    printbytes("tag", tag, 16);

    a.out_ptr = plain;
    a.plain_ptr = out;
    int ret = gcm128_decrypt(&a);
    printf("gcm_decrypt returned %d\n", ret);
    printbytes("plaintext", plain, 19);

    int nblocks = 256;
    byte *plain2 = new byte[nblocks * 16];
    byte *out2 = new byte[nblocks * 16];
    for (int i = 0; i < nblocks * 16; i++)
    {
        plain2[i] = i % 256;
    }
    a.plain_ptr = plain2;
    a.plain_num_bytes = nblocks * 16;
    a.out_ptr = out2;
    for (int i = 0; i < 10; i++)
    {
        auto time1 = std::chrono::high_resolution_clock::now();
        int n = 10000;
        for (int j = 0; j < n; j++)
        {
            gcm128_encrypt(&a);
        }
        auto time2 = std::chrono::high_resolution_clock::now();
        int dt = std::chrono::duration_cast<std::chrono::microseconds>(time2 - time1).count();
        printf("time = %d microseconds for %d iterations (%lf MB/s)\n", dt, n, double(n) * (nblocks * 16) / dt);
    }
    printbytes("cipher", out2, 16);
    printbytes("tag", tag, 16);

    printf("goodbye\n");
    return 0;
}
