/*****************************************************************************/
/* CascTest.cpp                           Copyright (c) Ladislav Zezula 2014 */
/*---------------------------------------------------------------------------*/
/* Test module for CascLib                                                   */
/*---------------------------------------------------------------------------*/
/*   Date    Ver   Who  Comment                                              */
/* --------  ----  ---  -------                                              */
/* 29.04.14  1.00  Lad  The first version of CascTest.cpp                    */
/*****************************************************************************/

#define _CRT_NON_CONFORMING_SWPRINTFS
#define _CRT_SECURE_NO_DEPRECATE
#define __INCLUDE_CRYPTOGRAPHY__
#define __CASCLIB_SELF__                    // Don't use CascLib.lib
#include <stdio.h>

#ifdef _MSC_VER
#include <crtdbg.h>
#endif

#include "CascLib.h"
#include "CascCommon.h"

#include "TLogHelper.mm"

#ifdef _MSC_VER
#pragma warning(disable: 4505)              // 'XXX' : unreferenced local function has been removed
#endif

#ifdef PLATFORM_LINUX
#include <dirent.h>
#endif

//------------------------------------------------------------------------------
// Defines

#ifdef PLATFORM_WINDOWS
#define WORK_PATH_ROOT "\\Multimedia\\MPQs"
#define MAKE_PATH(subdir)  (_T(WORK_PATH_ROOT) _T("\\") _T(subdir))
#endif

#ifdef PLATFORM_LINUX
#define WORK_PATH_ROOT "/home/ladik/MPQs"
#define MAKE_PATH(subdir)  (_T(WORK_PATH_ROOT) _T("/") _T(subdir))
#endif

#ifdef PLATFORM_MAC
#define WORK_PATH_ROOT "/Applications/World of Warcraft"
#define MAKE_PATH(subdir)  (_T(WORK_PATH_ROOT) _T("/") _T(subdir))
#define TMP_PATH "/tmp"
#endif



static const char szCircleChar[] = "|/-\\";

#if defined(_MSC_VER) && defined(_DEBUG)
#define GET_TICK_COUNT()  GetTickCount()
#else
#define GET_TICK_COUNT()  0
#endif

//-----------------------------------------------------------------------------
// Local functions

static bool IsEncodingKey(const char * szFileName)
{
    BYTE KeyBuffer[MD5_HASH_SIZE];

    // The length must be at least the length of the encoding key
    if(strlen(szFileName) < MD5_STRING_SIZE)
        return false;

    // Convert the BLOB to binary.
    if(ConvertStringToBinary(szFileName, MD5_STRING_SIZE, KeyBuffer) != ERROR_SUCCESS)
        return false;

    return true;
}

static int ForceCreatePath(TCHAR * szFullPath)
{
    TCHAR * szPlainName = (TCHAR *)GetPlainFileName(szFullPath) - 1;
    TCHAR * szPathPart = szFullPath;
    TCHAR chSaveChar;

    // Skip disk drive and root directory
    if(szPathPart[0] != 0 && szPathPart[1] == _T(':'))
        szPathPart += 3;

    while(szPathPart <= szPlainName)
    {
        // If there is a delimiter, create the path fragment
        if(szPathPart[0] == _T('\\') || szPathPart[0] == _T('/'))
        {
            chSaveChar = szPathPart[0];
            szPathPart[0] = 0;

            CREATE_DIRECTORY(szFullPath);
            szPathPart[0] = chSaveChar;
        }

        // Move to the next character
        szPathPart++;
    }

    return ERROR_SUCCESS;
}

static int ExtractFile(HANDLE hStorage, CASC_FIND_DATA & cf, const TCHAR * szLocalPath)
{
//  TFileStream * pStream = NULL;
    HANDLE hFile = NULL;
    BYTE Buffer[0x1000] = {0};
    DWORD dwBytesRead = -1;
    DWORD dwFlags = 0;
    bool bResult;
    int nError = ERROR_SUCCESS;
    TFileStream* pStream = NULL;

    // Keep compiler happy
    CASCLIB_UNUSED(szLocalPath);

    // Open the CASC file
    if(nError == ERROR_SUCCESS)
    {
        // Replace with encoding key
        if(cf.szFileName[0] == 0)
        {
            StringFromBinary(cf.FileKey, MD5_HASH_SIZE, cf.szFileName);
            dwFlags |= CASC_OPEN_BY_EKEY;
        }

        // Open a file
        if(!CascOpenFile(hStorage, cf.szFileName, cf.dwLocaleFlags, dwFlags, &hFile))
        {
            assert(GetLastError() != ERROR_SUCCESS);
            nError = GetLastError();
        }
    }

    //Create the local file
  if(nError == ERROR_SUCCESS)
  {
      TCHAR szLocalFileName[MAX_PATH];
      TCHAR * szNamePtr = szLocalFileName;
      
      // Create the file path
      _tcscpy(szNamePtr, szLocalPath);
      szNamePtr += _tcslen(szLocalPath);
      *szNamePtr++ = _T('/');
      CopyString(szNamePtr, cf.szFileName, strlen(cf.szFileName));
      pStream = FileStream_CreateFile(szLocalFileName, 0);
      if(pStream == NULL)
      {
          // Try to create all directories and retry
          ForceCreatePath(szLocalFileName);
          pStream = FileStream_CreateFile(szLocalFileName, 0);
          if(pStream == NULL)
              nError = GetLastError();
      }
  }

    // Read some data from the file
    while ((nError == ERROR_SUCCESS) && (dwBytesRead > 0))
    {
        // Read data from the file
        bResult = CascReadFile(hFile, Buffer, sizeof(Buffer), &dwBytesRead);
        if(bResult == false)
        {
            nError = GetLastError();
            break;
        }

        // Write the local file
        if(dwBytesRead > 0) {
            FileStream_Write(pStream, NULL, Buffer, dwBytesRead);
        }
    }

    // Log the file sizes
#ifdef CASCLIB_TEST
//  if(nError == ERROR_SUCCESS)
//  {
//      TCascFile * hf = IsValidFileHandle(hFile);
//
//      fprintf(fp, "%8u %8u %8u %8u %8u %s\n", hf->FileSize_RootEntry,
//                                              hf->FileSize_EncEntry,
//                                              hf->FileSize_IdxEntry,
//                                              hf->FileSize_HdrArea,
//                                              hf->FileSize_FrameSum,
//                                              szFileName);
//  }
#endif

     // Close handles
    if (pStream != NULL) {
        FileStream_Close(pStream);
        pStream = NULL;
    }
   
    if(hFile != NULL) {
        CascCloseFile(hFile);
        hFile = NULL;
    }
    return nError;
}

static int CompareFile(TLogHelper & LogHelper, HANDLE hStorage, CASC_FIND_DATA & cf, const TCHAR * szLocalPath)
{
    ULONGLONG FileSize = (ULONGLONG)-1;
    TFileStream * pStream = NULL;
    HANDLE hCascFile = NULL;
    LPBYTE pbFileData1 = NULL;
    LPBYTE pbFileData2 = NULL;
    TCHAR szFileName[MAX_PATH+1] = {0};
    TCHAR szTempBuff[MAX_PATH+1] = {0};
    DWORD dwFileSize1 = 0;
    DWORD dwFileSize2 = 0;
    DWORD dwBytesRead = 0;
    DWORD dwFlags = 0;
    int nError = ERROR_SUCCESS;

    // If we don't know the name, use the encoding key as name
    if(cf.szFileName[0] == 0)
    {
        StringFromBinary(cf.FileKey, MD5_HASH_SIZE, cf.szFileName);
        dwFlags |= CASC_OPEN_BY_EKEY;

        CopyString(szTempBuff, cf.szFileName, MAX_PATH);
        _stprintf(szFileName, _T("%s\\unknown\\%02X\\%s"), szLocalPath, cf.FileKey[0], szTempBuff);
    }
    else
    {
        CopyString(szTempBuff, cf.szFileName, MAX_PATH);
        _stprintf(szFileName, _T("%s\\%s"), szLocalPath, szTempBuff);
    }

    LogHelper.PrintProgress("Comparing %s ...", cf.szFileName);

    // Open the CASC file
    if(nError == ERROR_SUCCESS)
    {
        if(!CascOpenFile(hStorage, cf.szFileName, cf.dwLocaleFlags, dwFlags, &hCascFile))
            nError = LogHelper.PrintError("CASC file not found: %s", cf.szFileName);
    }

    // Open the local file
    if(nError == ERROR_SUCCESS)
    {
        pStream = FileStream_OpenFile(szFileName, STREAM_FLAG_READ_ONLY);
        if(pStream == NULL)
            nError = LogHelper.PrintError("Local file not found: %s", cf.szFileName);
    }

    // Retrieve the size of the file
    if(nError == ERROR_SUCCESS)
    {
        dwFileSize1 = CascGetFileSize(hCascFile, NULL);
        if(FileStream_GetSize(pStream, &FileSize))
            dwFileSize2 = (DWORD)FileSize;

        if(dwFileSize1 == CASC_INVALID_SIZE || dwFileSize2 == CASC_INVALID_SIZE)
        {
            nError = LogHelper.PrintError("Failed to get file size: %s", cf.szFileName);
        }
    }

    // The file sizes must match
    if(nError == ERROR_SUCCESS)
    {
        if(dwFileSize1 != dwFileSize2)
        {
            SetLastError(ERROR_FILE_CORRUPT);
            nError = LogHelper.PrintError("Size mismatch on %s", cf.szFileName);
        }
    }

    // Read the entire content to memory
    if(nError == ERROR_SUCCESS)
    {
        pbFileData1 = CASC_ALLOC(BYTE, dwFileSize1);
        pbFileData2 = CASC_ALLOC(BYTE, dwFileSize2);
        if(pbFileData1 == NULL || pbFileData2 == NULL)
        {
            SetLastError(ERROR_NOT_ENOUGH_MEMORY);
            nError = LogHelper.PrintError("Failed allocate memory");
        }
    }

    // Read the entire CASC file to memory
    if(nError == ERROR_SUCCESS)
    {
        if(!CascReadFile(hCascFile, pbFileData1, dwFileSize1, &dwBytesRead))
        {
            nError = LogHelper.PrintError("Failed to read casc file: %s", cf.szFileName);
        }
    }

    // Read the entire local file to memory
    if(nError == ERROR_SUCCESS)
    {
        if(!FileStream_Read(pStream, NULL, pbFileData2, dwFileSize2))
        {
            nError = LogHelper.PrintError("Failed to read local file: %s", cf.szFileName);
        }
    }

    // Compare both
    if(nError == ERROR_SUCCESS)
    {
        if(memcmp(pbFileData1, pbFileData2, dwFileSize1))
        {
            SetLastError(ERROR_FILE_CORRUPT);
            nError = LogHelper.PrintError("File data mismatch: %s", cf.szFileName);
        }
    }

    // Free both buffers
    if(pbFileData2 != NULL)
        CASC_FREE(pbFileData2);
    if(pbFileData1 != NULL)
        CASC_FREE(pbFileData1);
    if(pStream != NULL)
        FileStream_Close(pStream);
    if(hCascFile != NULL)
        CascCloseFile(hCascFile);
    return nError;
}

/*
//-----------------------------------------------------------------------------
// Testing functions

static int TestOpenStorage_OpenFile(const TCHAR * szStorage, const char * szFileName)
{
    TLogHelper LogHelper("OpenStorage");
    HANDLE hStorage;
    HANDLE hFile;
    DWORD dwFileSize2 = 0;
    DWORD dwFileSize1;
    DWORD dwFlags = 0;
    BYTE Buffer[0x1000];
    int nError = ERROR_SUCCESS;

    // Open the storage directory
    LogHelper.PrintProgress(_T("Opening storage \"%s\"..."), szStorage);
    if(!CascOpenStorage(szStorage, CASC_LOCALE_ENGB, &hStorage))
    {
        assert(GetLastError() != ERROR_SUCCESS);
        nError = GetLastError();
    }

    if(nError == ERROR_SUCCESS && szFileName != NULL)
    {
        // Check whether the name is the encoding key
        if(IsEncodingKey(szFileName))
            dwFlags |= CASC_OPEN_BY_EKEY;

        // Open a file
        LogHelper.PrintProgress("Opening file %s...", szFileName);
        if(CascOpenFile(hStorage, szFileName, 0, dwFlags, &hFile))
        {
            dwFileSize1 = CascGetFileSize(hFile, NULL);

            for(;;)
            {
                DWORD dwBytesRead = 0;

                CascReadFile(hFile, Buffer, sizeof(Buffer), &dwBytesRead);
                if(dwBytesRead == 0)
                    break;

                dwFileSize2 += dwBytesRead;
            }
            
            CascCloseFile(hFile);
        }
        else
        {
            assert(GetLastError() != ERROR_SUCCESS);
            nError = GetLastError();
        }
    }

    // Close storage and return
    if(hStorage != NULL)
        CascCloseStorage(hStorage);
    return nError;
}

static int PlatformUpdateFileData(const PCASC_FIND_DATA pFileData) {
    int nError = ERROR_SUCCESS;
    
    NSString *szFileNameSTR = [[NSString stringWithUTF8String:pFileData->szFileName] stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    strcpy(pFileData->szFileName, [szFileNameSTR cStringUsingEncoding:NSUTF8StringEncoding]);
    
    return nError;
}

static int TestOpenStorage_EnumFiles(const TCHAR * szStorage, const TCHAR * szListFile = NULL)
{
    CASC_FIND_DATA FindData;
    TLogHelper LogHelper("OpenForEnum");
    HANDLE hStorage;
    HANDLE hFind;
    DWORD dwTotalFiles = 0;
    DWORD dwFoundFiles = 0;
    DWORD dwCircleCount = 0;
    DWORD dwTickCount = 0;
    bool bFileFound = true;
    int nError = ERROR_SUCCESS;

    // Open the storage directory
    LogHelper.PrintProgress(_T("Opening storage %s ..."), szStorage);
    if(!CascOpenStorage(szStorage, 0, &hStorage))
    {
        assert(GetLastError() != ERROR_SUCCESS);
        nError = GetLastError();
    }

    if(nError == ERROR_SUCCESS)
    {
        // Retrieve the total number of files
        CascGetStorageInfo(hStorage, CascStorageFileCount, &dwTotalFiles, sizeof(dwTotalFiles), NULL);

        // Start finding
        LogHelper.PrintProgress("Searching storage ...");
        hFind = CascFindFirstFile(hStorage, "*", &FindData, szListFile);
        if(hFind != NULL)
        {
            dwTickCount = GET_TICK_COUNT();
            while(bFileFound)
            {
                //PlatformUpdateFileData(&FindData);
                // Extract the file
                if((dwFoundFiles % 400) == 0)
                {
                    LogHelper.PrintProgress("Enumerating files: %c", szCircleChar[dwCircleCount % 4]);
                    dwCircleCount++;
                }

                // Find the next file in CASC
                dwFoundFiles++;
                bFileFound = CascFindNextFile(hFind, &FindData);
            }

            dwTickCount = GET_TICK_COUNT() - dwTickCount;

            // Just a testing call - must fail
            CascFindNextFile(hFind, &FindData);

            // Close the search handle
            CascFindClose(hFind);
            LogHelper.PrintProgress("");
        }
    }

    // Close storage and return
    if(hStorage != NULL)
        CascCloseStorage(hStorage);
    return nError;
}
*/

static int TestOpenStorage_ExtractFiles(const TCHAR * szStorage, const TCHAR * szTargetDir, const TCHAR * szListFile)
{
    CASC_FIND_DATA FindData;
    TLogHelper LogHelper("OpenForExtract");
    HANDLE hStorage;
    HANDLE hFind;
    bool bFileFound = true;
    int nError = ERROR_SUCCESS;

    // Open the storage directory
    LogHelper.PrintProgress(_T("Opening storage %s ..."), szStorage);
    if(!CascOpenStorage(szStorage, 0, &hStorage))
    {
        assert(GetLastError() != ERROR_SUCCESS);
        nError = GetLastError();
    }
    
    if(nError == ERROR_SUCCESS)
    {
         DWORD dwTotalFiles = 0;
        // Retrieve the total number of files
        CascGetStorageInfo(hStorage, CascStorageFileCount, &dwTotalFiles, sizeof(dwTotalFiles), NULL);
        
        // Start finding
        LogHelper.PrintProgress("Searching storage ...");
        hFind = CascFindFirstFile(hStorage, "*", &FindData, szListFile);
        if(hFind != INVALID_HANDLE_VALUE)
        {
            // Search the storage
            while(bFileFound)
            {
                //PlatformUpdateFileData(&FindData);
                // Extract the file
                LogHelper.PrintProgress("Extracting %s ...", FindData.szPlainName);
                nError = ExtractFile(hStorage, FindData, szTargetDir);
                if(nError != ERROR_SUCCESS)
                    LogHelper.PrintError("Extracting %s .. Failed", FindData.szPlainName);

                // Compare the file with the local copy
//              CompareFile(LogHelper, hStorage, FindData, szTargetDir);

                // Find the next file in CASC
                bFileFound = CascFindNextFile(hFind, &FindData);
            }

            // Close the search handle
            CascFindClose(hFind);
            LogHelper.PrintProgress("");
        }
    }

    // Close storage and return
    if(hStorage != NULL)
        CascCloseStorage(hStorage);
    return nError;
}

static int TestOpenStorage_GetFileDataId(const TCHAR * szStorage, const char * szFileName, DWORD expectedId)
{
    TLogHelper LogHelper("GetFileDataId");
    HANDLE hStorage;
    int nError = ERROR_FILE_NOT_FOUND;

    // Open the storage directory
    LogHelper.PrintProgress("Opening storage ...");
    if(!CascOpenStorage(szStorage, 0, &hStorage))
    {
        assert(GetLastError() != ERROR_SUCCESS);
        nError = GetLastError();
    }
    else
    {
        nError = ERROR_SUCCESS;
    }

    if(nError == ERROR_SUCCESS)
    {
        if(CascGetFileId(hStorage, szFileName) != expectedId)
            nError = ERROR_BAD_FORMAT;
    }

    // Close storage and return
    if(hStorage != NULL)
        CascCloseStorage(hStorage);
    return nError;
}

//-----------------------------------------------------------------------------
// Main

int mainCascTest(int argc, const char * argv[])
{
    const TCHAR * szListFile = _T("./listfile.txt");
    int nError = ERROR_SUCCESS;

    // Keep compiler happy
    szListFile = szListFile;
    argc = argc;
    argv = argv;

#if defined(_MSC_VER) && defined(_DEBUG)
    _CrtSetDbgFlag(_CRTDBG_ALLOC_MEM_DF | _CRTDBG_LEAK_CHECK_DF);
#endif  // defined(_MSC_VER) && defined(_DEBUG)

//  if(nError == ERROR_SUCCESS)
//      nError = Hack();
    
    nError = ERROR_SUCCESS;
    //nError = TestOpenStorage_EnumFiles(MAKE_PATH("Data"), szListFile);
    nError = TestOpenStorage_ExtractFiles(MAKE_PATH("Data"), TMP_PATH, szListFile);
    //nError = TestOpenStorage_GetFileDataId(MAKE_PATH("Data"), "character/bloodelf/female/bloodelffemale.m2", 116921);

#ifdef _MSC_VER                                                          
    _CrtDumpMemoryLeaks();
#endif  // _MSC_VER

    return nError;
}

int main(int argc, const char * argv[]) {
    int result = 0;
    @autoreleasepool {
        // insert code here...
        NSLog(@"\n\nHello\n assuming WoW is installed at \"%s\"\n Will extract files to \"%s\"\n\n", WORK_PATH_ROOT, TMP_PATH);
        result = mainCascTest(argc, argv);
    }
    return result;
}

