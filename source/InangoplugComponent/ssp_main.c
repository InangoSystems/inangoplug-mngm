/*
 * If not stated otherwise in this file or this component's Licenses.txt file the
 * following copyright and licenses apply:
 *
 * Copyright 2017 RDK Management
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
*/

/*
 * Includes Inango Systems Ltd's changes/modifications dated: 2021.
 * Changed/modified portions - Copyright (c) 2021, Inango Systems Ltd.
*/

/*********************************************************************************

    description:

        This is the template file of ssp_main.c for XxxxSsp.
        Please replace "XXXX" with your own ssp name with the same up/lower cases.

  ------------------------------------------------------------------------------

    revision:

        09/08/2011    initial revision.

**********************************************************************************/


#ifdef __GNUC__
#ifndef _BUILD_ANDROID
#include <execinfo.h>
#endif
#endif

#include "ssp_global.h"
#include "stdlib.h"
#include "ccsp_dm_api.h"
#include <syscfg/syscfg.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include "inangoplug_log.h"

extern ANSC_HANDLE                          bus_handle;
extern char*                                pComponentName;
char                                        g_Subsystem[32]         = {0};
char                                        sc_privkey[64]          = "/sc-privkey.pem";
char                                        sc_cert[64]             = "/sc-cert.pem";
char                                        ca_cert[64]             = "/cacert.pem";

static inline void set_path(const char * path, char * buff) {
    char * tmp = getenv(path);
    if (tmp == NULL || strlen(tmp) == 0)
    {
        inangoplug_log_error("Path: %s is not set!\n", path);
        return;
    }
    memmove(&buff[strlen(tmp)], buff, strlen(buff));
    memmove(buff, tmp, strlen(tmp));
    inangoplug_log_info("Get config: %s\n", buff);
}

void read_file(const char * path, char * source, ULONG * size) {
    FILE *file;
    file = fopen(path, "r");
    if(!file)
    {
        inangoplug_log_error("Failed to read: file: %s , source: %s , size: %lu\n", path, source, size);
        return;
    }
    fread(source, sizeof(char), size, file);
    fclose(file);
}

void write_to_file(const char * path, char * source) {
    FILE *file;
    file = fopen(path, "w");
    if(!file)
    {
        inangoplug_log_error("Failed to write: file: %s , source: %s\n", path, source);
        return;
    }
    fwrite(source, sizeof(char), strlen(source), file);
    fclose(file);
}

/*
 * Some ACS servers can not send string with new line characters and replaced it with spaces.
 * Correct format key and certificates should be with new lines instead of spaces.
 */
void replace_spaces(char* s) {
    int count = 0;
    int i = 0;
    char* d = s;

    do 
    {
        if(*d == '-')
        {
            i++;
            if (i == 5)
            {
                count++;
                i = 0;
            }
            continue;
        }
        
        if (count <= 1)
        {
            continue;
        }
        
        if (count == 3)
        {
            break;
        }

        while (*d == ' ') 
        {
            *d = '\n';
        }
    } while (*s++ = *d++); 
}

void get_datapath_id(char * buf, ULONG * size)
{
    FILE *fp;
    char * estr;
    fp = popen("ovs-vsctl get bridge brlan0 other-config:datapath-id 2>&1 | sed -e 's/\"//g'", "r");

    if (fp == NULL)
    {
        inangoplug_log_error("Failed to get datapath-id\n");
        pclose(fp);
        return;
    }

    estr = fgets(buf, *size, fp);
    if (estr == NULL && feof(fp) == 0)
    {
        inangoplug_log_error("fgets() error to get datapath-id\n");
        pclose(fp);
        return;
    }

    pclose(fp);

    /* Parse error message from ovs or datapath_id is null */
    if (strstr(buf, "ovs-vsctl:") || buf[0] == '\0')
    {
        inangoplug_log_error("Datapath-id ovs error: %s\n", buf);
        memset(buf, 0, *size);
        return;
    }

    buf[strcspn(buf, "\n")] = 0;
    inangoplug_log_info("Datapath-id: %s\n", buf);
    return;
}

int  cmd_dispatch(int  command)
{
    switch ( command )
    {
        case    'e' :

#ifdef _ANSC_LINUX
            inangoplug_log_info("Connect to bus daemon...\n");

            {
                char                            CName[256];

                if ( g_Subsystem[0] != 0 )
                {
                    _ansc_sprintf(CName, "%s%s", g_Subsystem, CCSP_COMPONENT_ID_INANGOPLUGCOMPONENT);
                }
                else
                {
                    _ansc_sprintf(CName, "%s", CCSP_COMPONENT_ID_INANGOPLUGCOMPONENT);
                }

                ssp_Mbi_MessageBusEngage
                    ( 
                        CName,
                        CCSP_MSG_BUS_CFG,
                        CCSP_COMPONENT_PATH_INANGOPLUGCOMPONENT
                    );
            }
#endif

            ssp_create();
            ssp_engage();

            break;

        case    'm':

                AnscPrintComponentMemoryTable(pComponentName);

                break;

        case    't':

                AnscTraceMemoryTable();

                break;

        case    'c':
                
                ssp_cancel();

                break;

        default:
            break;
    }

    return 0;
}

static void _print_stack_backtrace(void)
{
#ifdef __GNUC__
#ifndef _BUILD_ANDROID
	void* tracePtrs[100];
	char** funcNames = NULL;
	int i, count = 0;

	count = backtrace( tracePtrs, 100 );
	backtrace_symbols_fd( tracePtrs, count, 2 );

	funcNames = backtrace_symbols( tracePtrs, count );

	if ( funcNames ) {
            // Print the stack trace
	    for( i = 0; i < count; i++ )
		printf("%s\n", funcNames[i] );

            // Free the string pointers
            free( funcNames );
	}
#endif
#endif
}

#if defined(_ANSC_LINUX)
static void daemonize(void) {
	int fd;
	switch (fork()) {
	case 0:
		break;
	case -1:
		// Error
		inangoplug_log_info("Error daemonizing (fork)! %d - %s\n", errno, strerror(errno));
		exit(0);
		break;
	default:
		_exit(0);
	}

	if (setsid() < 	0) {
		inangoplug_log_info("Error demonizing (setsid)! %d - %s\n", errno, strerror(errno));
		exit(0);
	}

//	chdir("/");


#ifndef  _DEBUG

	fd = open("/dev/null", O_RDONLY);
	if (fd != 0) {
		dup2(fd, 0);
		close(fd);
	}
	fd = open("/dev/null", O_WRONLY);
	if (fd != 1) {
		dup2(fd, 1);
		close(fd);
	}
	fd = open("/dev/null", O_WRONLY);
	if (fd != 2) {
		dup2(fd, 2);
		close(fd);
	}
#endif
}

void sig_handler(int sig)
{
    if ( sig == SIGINT ) {
    	signal(SIGINT, sig_handler); /* reset it to this function */
    	inangoplug_log_info("SIGINT received!\n");
	exit(0);
    }
    else if ( sig == SIGUSR1 ) {
    	signal(SIGUSR1, sig_handler); /* reset it to this function */
    	inangoplug_log_info("SIGUSR1 received!\n");
        INANGOPLUG_RDKLogLevel = GetLogInfo(bus_handle,"eRT.","Device.LogAgent.X_INANGO_Inangoplug_LogLevel");
        INANGOPLUG_RDKLogEnable = (char)GetLogInfo(bus_handle,"eRT.","Device.LogAgent.X_INANGO_Inangoplug_LoggerEnable");
    }
    else if ( sig == SIGUSR2 ) {
        signal(SIGUSR2, sig_handler); /* reset it to this function */
    	inangoplug_log_info("SIGUSR2 received!\n");
    }
    else if ( sig == SIGCHLD ) {
    	signal(SIGCHLD, sig_handler); /* reset it to this function */
    	inangoplug_log_info("SIGCHLD received!\n");
    }
    else if ( sig == SIGPIPE ) {
    	signal(SIGPIPE, sig_handler); /* reset it to this function */
    	inangoplug_log_info("SIGPIPE received!\n");
    }
    else {
    	/* get stack trace first */
    	_print_stack_backtrace();
    	inangoplug_log_info("Signal %d received, exiting!\n", sig);
    	exit(0);
    }

}

#endif
int main(int argc, char* argv[])
{
    ANSC_STATUS                     returnStatus       = ANSC_STATUS_SUCCESS;
    BOOL                            bRunAsDaemon       = TRUE;
    int                             cmdChar            = 0;
    int                             idx = 0;
    int                             fd;
    char                            cmd[64]            = {0};
    char *subSys            = NULL;  
    DmErr_t    err;

    for (idx = 1; idx < argc; idx++)
    {
        if ( (strcmp(argv[idx], "-subsys") == 0) )
        {
            AnscCopyString(g_Subsystem, argv[idx+1]);
        }
        else if ( strcmp(argv[idx], "-c") == 0 )
        {
            bRunAsDaemon = FALSE;
        }
    }

    pComponentName          = CCSP_COMPONENT_NAME_INANGOPLUGCOMPONENT;

#if  defined(_ANSC_WINDOWSNT)

    AnscStartupSocketWrapper(NULL);

    cmd_dispatch('e');

    while ( cmdChar != 'q' )
    {
        cmdChar = getchar();

        cmd_dispatch(cmdChar);
    }
#elif defined(_ANSC_LINUX)
    if ( bRunAsDaemon ) 
        daemonize();

    fd = fopen("/var/run/inangoplug_component.pid", "w+");
    if ( !fd )
    {
        inangoplug_log_warning("Create /var/run/inangoplug_component.pid error. \n");
        return 1;
    }
    else
    {
        sprintf(cmd, "%d", getpid());
        fputs(cmd, fd);
        fclose(fd);
    }

    signal(SIGTERM, sig_handler);
    signal(SIGINT, sig_handler);
    /*signal(SIGCHLD, sig_handler);*/
    signal(SIGUSR1, sig_handler);
    signal(SIGUSR2, sig_handler);

    signal(SIGSEGV, sig_handler);
    signal(SIGBUS, sig_handler);
    signal(SIGKILL, sig_handler);
    signal(SIGFPE, sig_handler);
    signal(SIGILL, sig_handler);
    signal(SIGQUIT, sig_handler);
    signal(SIGHUP, sig_handler);

    cmd_dispatch('e');
#ifdef _COSA_SIM_
    subSys = "";        /* PC simu use empty string as subsystem */
#else
    subSys = NULL;      /* use default sub-system */
#endif
    err = Cdm_Init(bus_handle, subSys, NULL, NULL, pComponentName);
    if (err != CCSP_SUCCESS)
    {
        fprintf(stderr, "Cdm_Init: %s\n", Cdm_StrError(err));
        exit(1);
    }
    syscfg_init();
    inangoplug_log_init();
    set_path("CONFIG_INANGO_INANGOPLUG_SSL_DIR", sc_privkey);
    if (sc_privkey == NULL)
    {
        exit(1);
    }
    set_path("CONFIG_INANGO_INANGOPLUG_SSL_DIR", sc_cert);
    if (sc_cert == NULL)
    {
        exit(1);
    }
    set_path("CONFIG_INANGO_INANGOPLUG_SSL_DIR", ca_cert);
    if (ca_cert == NULL)
    {
        exit(1);
    }
    system("touch /tmp/inangoplugcomponent_initialized");

    if ( bRunAsDaemon )
    {
        while(1)
        {
            sleep(30);
        }
    }
    else
    {
        while ( cmdChar != 'q' )
        {
            cmdChar = getchar();

            cmd_dispatch(cmdChar);
        }
    }

#endif
	err = Cdm_Term();
	if (err != CCSP_SUCCESS)
	{
	fprintf(stderr, "Cdm_Term: %s\n", Cdm_StrError(err));
	exit(1);
	}

	ssp_cancel();

    return 0;
}

