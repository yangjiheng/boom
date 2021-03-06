//
//  main.m
//  boom
//
//  Created by Jason Yang on 2018/10/3.
//  Copyright © 2018年 . All rights reserved.
//

#import <Foundation/Foundation.h>
#import <URKArchive.h>
#import <URKFileinfo.h>
#import <SSZipArchive.h>

#include <unistd.h>

int boomRarFile(const char *filename, const char *outputPath, const char *password) {
    NSError *archiveError = nil;
    URKArchive *archive = [[URKArchive alloc] initWithPath:[NSString stringWithCString:filename encoding:NSUTF8StringEncoding] error:&archiveError];
    
    if (archiveError != nil) {
        NSLog(@"Creating archive failed\n");
        return -1;
    }
    
    NSError *error = nil;
    
    if (archive.isPasswordProtected) {
        if(password == NULL) {
            NSLog(@"Archive is password protected, please specify password\n");
            return -1;
        }
        archive.password = [NSString stringWithCString:password encoding:NSUTF8StringEncoding];
    }
    
    BOOL extractFilesSuccessful = [archive extractFilesTo:[NSString stringWithCString:outputPath encoding:NSUTF8StringEncoding]
                                                overwrite:NO
                                                 progress:^(URKFileInfo *currentFile, CGFloat percentArchiveDecompressed) {
                                                     NSLog(@"Extracting %@: %f%% complete", currentFile.filename, percentArchiveDecompressed);
                                                 }
                                                    error:&error];
    
    if(error != nil && extractFilesSuccessful != YES) {
        return -1;
    }
    
    return 0;
}

int boomZipFile(const char* filename, const char *outputPath, const char *password) {
    NSString *passwordString = nil;
    if (password != NULL) {
        passwordString = [NSString stringWithCString:password encoding:NSUTF8StringEncoding];
    }
    BOOL success = [SSZipArchive unzipFileAtPath:[NSString stringWithCString:filename encoding:NSUTF8StringEncoding]
                                   toDestination:[NSString stringWithCString:outputPath encoding:NSUTF8StringEncoding]
                              preserveAttributes:YES
                                       overwrite:YES
                                  nestedZipLevel:0
                                        password:passwordString.length > 0 ? passwordString : nil
                                           error:nil
                                        delegate:nil
                                 progressHandler:^(NSString * _Nonnull entry, unz_file_info zipInfo, long entryNumber, long total) {
                                     NSLog(@"Exracting %f%% complete\n", (float)entryNumber/(float)total);
                                 }
                               completionHandler:^(NSString * _Nonnull path, BOOL succeeded, NSError * _Nullable error) {
                                   NSLog(@"Extraction complete\n");
                               }];
    
    if (success != YES) {
        return -1;
    }
    else {
        return 0;
    }
}

BOOL createOutputPath(const char *path) {
    BOOL isDir = NO;
    NSError *error = nil;
    NSString *pathString = [NSString stringWithCString:path encoding:NSUTF8StringEncoding];

    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:pathString isDirectory:&isDir];
    
    if (fileExists) {
        if (isDir) {
            return YES;
        }
        return NO;
    }
    else {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:pathString
                                       withIntermediateDirectories:NO
                                                        attributes:nil
                                                             error:&error]) {
            // Creating directory failed
            return NO;
        }
        return YES;
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        int oc;
        const char *inputfile = NULL;
        const char *outputpath = NULL;
        const char *password = NULL;
        
        while ((oc = getopt(argc, (char *const *)argv, "i:o:p:")) != -1) {
            switch(oc) {
                case 'i':
                    inputfile = optarg;
                    break;
                case 'o':
                    outputpath = optarg;
                    break;
                case 'p':
                    password = optarg;
                    break;
                default:
                    break;
            }
        }
        
        if (inputfile==NULL || outputpath==NULL) {
            NSLog(@"Usage: boom -i <inputfile> -o <output path> -p <password>\n");
            return -1;
        }
        
        // Check output path to see whether it exists, if not create it.
        if (createOutputPath(outputpath) != YES) {
            NSLog(@"Cannot create output path :%s\n", outputpath);
            return -1;
        }
        
        NSString *inputfileString = [NSString stringWithCString:inputfile encoding:NSUTF8StringEncoding];
        
        int (*boomFunc)(const char *, const char *, const char *);
        if ([inputfileString hasSuffix:@".rar"]) {
            boomFunc = &boomRarFile;
        }
        else if ([inputfileString hasSuffix:@".zip"]) {
            boomFunc = &boomZipFile;
        }
        else {
            NSLog(@"Invalid file specified\n");
            return -1;
        }

        if (boomFunc(inputfile, outputpath, password) < 0) {
            NSLog(@"Booming %s failed\n", argv[1]);
            return -1;
        }
        else {
            NSLog(@"Booming %s to %s successed\n", inputfile, outputpath);
            return 0;
        }
    }
    return 0;
}
