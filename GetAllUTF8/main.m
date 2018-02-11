//
//  main.m
//  GetAllUTF8
//
//  Created by houkangzhu on 2018/2/9.
//  Copyright © 2018年 houkangzhu. All rights reserved.
//

#import <Foundation/Foundation.h>

// 每个文件字符数
static const NSInteger PART_CHAR_LENTH = 10240;
// 保存的路径
static NSString *__ResultPath = nil;
void setupFilePath(void) {
    __ResultPath = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES).firstObject;
    __ResultPath = [__ResultPath stringByAppendingPathComponent:@"字符大全"];
    NSFileManager *fManager = [NSFileManager defaultManager];
    if ([fManager fileExistsAtPath:__ResultPath]) {
        [fManager removeItemAtPath:__ResultPath error:nil];
    }
    [fManager createDirectoryAtPath:__ResultPath withIntermediateDirectories:YES attributes:nil error:nil];
}

void getAllUtf8Char(void) {
    NSMutableString *str = [NSMutableString string];
    __block NSInteger partCount = 0;
    void (^write_part_block)(NSString *) = ^(NSString *string) {
        NSString *partPath = [NSString stringWithFormat:@"%@/part_%ld.txt",__ResultPath, partCount];
        [string writeToFile:partPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        partCount ++;
    };
    
    int64_t i = 0;
    int64_t char_count = 0;
    while (i <= 0xFFFFFFFFFFFF) {
        i ++;
        Byte strByte[6] = {0};
        int8_t len = 0;
        Byte head = 0;
        if (i <= 0xFF) { // 1B
            len = 1;
        }
        else if (i <= 0xFFFF) { // 2B
            len = 2;
            head = 0b11011111;
        }
        else if (i <= 0xFFFFFF) { // 3B
            len = 3;
            head = 0b11101111;
        }
        else if (i <= 0xFFFFFFFF) { // 4B
            len = 4;
            head = 0b11110111;
        }
        else if (i <= 0xFFFFFFFFFF) { // 5B
            len = 5;
            head = 0b11111011;
        }
        else {  // 6B
            len = 6;
            head = 0b11111101;
        }
        if (len == 1) {
            if (i>>7 != 0) continue;
            strByte[0] = (Byte)(i&0b01111111);
        }
        else {
            BOOL exist = NO;
            for (int8_t j=0; j<len; j++) {
                Byte bc = ((i >> ((len-j-1)*8)) & 0xFF);
                if (j == 0) {
                    if((bc >> (8-len)) != (head >> (8-len))) {
                        exist = YES;
                        break;
                    }
                    strByte[0] = (bc & head);
                }
                else {
                    if (bc >> 6 != 0b10) {
                        exist = YES;
                        break;
                    }
                    strByte[j] = (bc & 0b10111111);
                }
            }
            if (exist) continue;
        }
        NSString *charStr = [[NSString alloc] initWithBytes:strByte
                                                     length:len
                                                   encoding:NSUTF8StringEncoding];
        if (charStr.length == 1 || charStr.length == 2) {
            [str appendString:charStr];
            char_count ++;
            if (char_count % PART_CHAR_LENTH == 0) {
                write_part_block(str);
                str = [NSMutableString string];
            }
        }
    }
    write_part_block(str);
}

// 获取多位时的最大和最小值
static uint64 getBorderNumber(uint8 len, BOOL start) {
    Byte *bytes = malloc(sizeof(Byte) * len);
    Byte header = ~(1<<(7-len));
    Byte other = start ? 0x80 : 0xBF;  // 1000_0000, 1011_1111
    if (start) {
        header = ((header >> (8-len)) << (8-len));
    }
    bytes[0] = header;
    for (uint8 i = 1; i < len; i++) {
        bytes[i] = other;
    }
    
    uint64 result = 0;
    for (int ix = 0; ix < len; ++ix) {
        result <<= 8;
        result |= (bytes[ix] & 0xFF);
    }
    free(bytes);
    return result;
}
// 高效版
void getAllUtf8Char2(void) {
    __block NSMutableString *resultString = [NSMutableString string];
    __block NSInteger partCount = 0;
    __block int64_t char_count = 0;
    void (^writeBytesBlock)(void *, uint) = ^ (void *strBytes, uint len) {
        NSString *charStr = [[NSString alloc] initWithBytes:strBytes
                                                     length:len
                                                   encoding:NSUTF8StringEncoding];
        if (charStr.length == 1 || charStr.length == 2) {
            [resultString appendString:charStr];
            char_count ++;
            if (char_count % PART_CHAR_LENTH == 0) {
                NSString *partPath = [NSString stringWithFormat:@"%@/part_%ld.txt",__ResultPath, partCount];
                [resultString writeToFile:partPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
                resultString = [NSMutableString string];
                partCount ++;
            }
        }
    };
    
    {   // 1位的
        for (uint8 i_1 = 0; i_1 <= 0x7F; i_1 ++) {
            Byte strByte = (Byte)(i_1&0x7F);
            writeBytesBlock(&strByte, 1);
        }
    }
    {   // 多位的
        void(^other_byte_block)(uint8) = ^(uint8 len) {
            Byte strBytes[6] = {0};
            Byte head_byte = ~(1<<(7-len));
            uint64 start = getBorderNumber(len, YES);
            uint64 end = getBorderNumber(len, NO);
            
            for (uint64 i_s = start; i_s <= end; i_s ++) {
                for (int8_t j=0; j<len; j++) {
                    Byte bc = ((i_s >> ((len-j-1)*8)) & 0xFF);
                    if (j == 0) {
                        strBytes[0] = (bc & head_byte);
                    }
                    else {
                        strBytes[j] = (bc & 0xBF);
                    }
                }
                writeBytesBlock(strBytes, len);
            }
            NSLog(@"");
        };
        other_byte_block(2);
        other_byte_block(3);
        other_byte_block(4);
        other_byte_block(5);
        other_byte_block(6);
    }
    
    NSString *partPath = [NSString stringWithFormat:@"%@/part_%ld.txt",__ResultPath, partCount];
    [resultString writeToFile:partPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        setupFilePath();
        getAllUtf8Char2();
    }
    return 0;
}
