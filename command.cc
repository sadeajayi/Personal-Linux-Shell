
/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <string.h>
#include <signal.h>
#include <fcntl.h>
#include "command.h"
#include <regex.h>
#include <pwd.h>

extern char **environ;

SimpleCommand::SimpleCommand()
{
	// Creat available space for 5 arguments
	_numberOfAvailableArguments = 5;
	_numberOfArguments = 0;
	_arguments = (char **) malloc( _numberOfAvailableArguments * sizeof( char * ) );
}

void
SimpleCommand::insertArgument( char * argument )
{

	if ( _numberOfAvailableArguments == _numberOfArguments  + 1 ) {
		// Double the available space
		_numberOfAvailableArguments *= 2;
		_arguments = (char **) realloc( _arguments,
				  _numberOfAvailableArguments * sizeof( char * ) );
	}
       
       	//environment variables expansion
	char *compare = (char *)malloc(1024);
	char *buffer = (char *)malloc(1024);
	int start = 0;
	int end = 0;
	int result = 0;
	if(strchr(argument, '$')) 
	{
		while( argument[start] != '\0') 
		{
			if(argument[start] == '$')
			{
				start = start + 2;
				while(argument[start] != '}')
				{
					compare[end] = argument[start];
					start++;
					end++;
				}
				compare[end] = '\0';
				strcat(buffer, getenv(compare));
				//end = 0;
				result+= strlen(getenv(compare));
				end = 0;
			}
			else { 
				buffer[result] = argument[start];		
				result++;
			}
			start++;
		}
		buffer[start] = '\0';
		argument = strdup(buffer);
	}

	char * variable ;
	//tilde expansion
	if(argument[0] == '~'){
		if(strlen(argument)== 1){
			variable = strdup(getenv("HOME"));
		}
		else {
			variable = strdup(getpwnam(argument+1)->pw_dir);
		}
	}
	else {
		variable = strdup(argument);
	}
	_arguments[ _numberOfArguments ] = strdup(variable);

	// Add NULL argument at the end
	_arguments[ _numberOfArguments + 1] = NULL;
	
	_numberOfArguments++;
}

Command::Command()
{
	// Create available space for one simple command
	_numberOfAvailableSimpleCommands = 1;
	_simpleCommands = (SimpleCommand **)
		malloc( _numberOfSimpleCommands * sizeof( SimpleCommand * ) );

	_numberOfSimpleCommands = 0;
	_outFile = 0;
	_inputFile = 0;
	_errFile = 0;
	_background = 0;
	_appender = 0;
}

void
Command::insertSimpleCommand( SimpleCommand * simpleCommand )
{
	if ( _numberOfAvailableSimpleCommands == _numberOfSimpleCommands ) {
		_numberOfAvailableSimpleCommands *= 2;
		_simpleCommands = (SimpleCommand **) realloc( _simpleCommands,
			 _numberOfAvailableSimpleCommands * sizeof( SimpleCommand * ) );
	}
	
	_simpleCommands[ _numberOfSimpleCommands ] = simpleCommand;
	_numberOfSimpleCommands++;
}

void
Command:: clear()
{
	for ( int i = 0; i < _numberOfSimpleCommands; i++ ) {
		for ( int j = 0; j < _simpleCommands[ i ]->_numberOfArguments; j ++ ) {
			free ( _simpleCommands[ i ]->_arguments[ j ] );
		}
		
		free ( _simpleCommands[ i ]->_arguments );
		delete  _simpleCommands[ i ] ;
	}

	if ( _outFile ) {
		free( _outFile );
	}

	if ( _inputFile ) {
		free( _inputFile );
	}

	if ( _errFile && _errFile != _outFile ) {
		free( _errFile );
	}

	_numberOfSimpleCommands = 0;
	_outFile = 0;
	_inputFile = 0;
	_errFile = 0;
	_background = 0;
	_appender = 0;
}

void
Command::print()
{
	printf("\n\n");
	printf("              COMMAND TABLE                \n");
	printf("\n");
	printf("  #   Simple Commands\n");
	printf("  --- ----------------------------------------------------------\n");
	
	for ( int i = 0; i < _numberOfSimpleCommands; i++ ) {
		printf("  %-3d ", i );
		for ( int j = 0; j < _simpleCommands[i]->_numberOfArguments; j++ ) {
			printf("\"%s\" \t", _simpleCommands[i]->_arguments[ j ] );
		}
	}

	printf( "\n\n" );
	printf( "  Output       Input        Error        Background\n" );
	printf( "  ------------ ------------ ------------ ------------\n" );
	printf( "  %-12s %-12s %-12s %-12s\n", _outFile?_outFile:"default",
		_inputFile?_inputFile:"default", _errFile?_errFile:"default",
		_background?"YES":"NO");
	printf( "\n\n" );
	
}

void
Command::execute()
{
	// Don't do anything if there are no simple commands
	if ( _numberOfSimpleCommands == 0 ) {
		prompt();
		return;
	}
	// Print contents of Command data structure
	//print();

	// Add execution here
	int defin = dup(0);
	int defout = dup(1);
	int deferr = dup(2);

	int fdin;
	int fdout;
	int fderr;
	int fdpipe[(_numberOfSimpleCommands - 1)*2];

	for(int i = 0; i <_numberOfSimpleCommands-1; i++){
		if(pipe(fdpipe + i*2) < 0) {
			perror("Pipe ERROR!");
			exit(1);
		}
	}

	if(_inputFile != 0) {
		fdin = open(_inputFile,0600);
		dup2(fdin, 0);
	}
	else {
		dup2(defin, 0);
	}
	// For every simple command fork a new process

	int forker;
	for(int i =0; i <_numberOfSimpleCommands; i++) {
		if(!strcmp(_simpleCommands[i]->_arguments[0], "exit")) {
			printf("Good bye!!");
			exit(1);
		}

		
		if (!strcmp( _simpleCommands[i]->_arguments[0], "setenv")) {
			setenv(_simpleCommands[i]->_arguments[1], _simpleCommands[i]->_arguments[2], 1);
			clear();
			prompt();
			return;
		}

		if (!strcmp(_simpleCommands[i]->_arguments[0], "cd")) {
			if(_simpleCommands[i]->_arguments[1] == NULL) {
				chdir(getenv("HOME"));
			}
			else {
				chdir(_simpleCommands[0]->_arguments[1]);
			}
			clear();
			prompt();
			return;
		}	


		if (!strcmp( _simpleCommands[i]->_arguments[0], "unsetenv")) {
		 	unsetenv(_simpleCommands[i]->_arguments[1]);
			clear();
			prompt();
			return;
		}	 
		if(i ==_numberOfSimpleCommands-1) {
			if(_outFile != 0) {
			  if(_appender) {
				fdout = open(_outFile, O_APPEND | O_WRONLY | O_CREAT, 0600);
			  }
			  else {
				fdout = creat(_outFile, 0600);
			  }
			  dup2(fdout, 1);
			}
			else {
				dup2(defout, 1);
			}
			if(_errFile != 0) {
				dup2(fdout, 2);
			}
			else {
				dup2(deferr, 2);
			}
		}
		else {
			//create pipe
			dup2(fdpipe[2*i +1], 1);
		}
		if(i != 0) {
			dup2(fdpipe[(i-1)*2], 0);
		}

		forker = fork();
		if(forker == 0) { //child
			execvp(_simpleCommands[i]->_arguments[0],_simpleCommands[i]->_arguments);
			perror(_simpleCommands[i]->_arguments[0]);
			//perror("execvp");
			close(fdin);
			close(fdout);
			close(fdpipe[(i-1)*2]);
			exit(1);
		}
		else if(forker < 0) {
			perror("fork");
			return;
		}
		else {
			close(fdpipe[(2*i) + 1]);		
		}
	}//end of for loop

	 dup2(defin, 0);
	 dup2(defout, 1);
	 dup2(deferr, 2);
	 close(defin);
	 close(defout);
	 close(deferr);
	
	if(!_background){
		waitpid(forker, NULL, 0);
	}	

	// Clear to prepare for next command
	clear();
	
	// Print new prompt
	prompt();
}

// Shell implementation

extern "C" void disp(int sig)
{
	int status;
	wait3(&status,0,NULL); 
	Command::_currentCommand.prompt();
	//fprintf( stderr, "\n       Ouch!\n");
}

void
Command::prompt()
{
	if (isatty(0))
    {
		printf("myshell>");
		fflush(stdout);
	}
}

extern "C" void killzombie(int sig)
{//wait until the child process terminates

    int pid = wait3(0, 0, NULL);
    while(waitpid(-1, NULL, WNOHANG) > 0); //return immediately if no child has exited
    
    if (pid == 1)
    {
        printf("[%d] exited.\n", pid);    
        Command::_currentCommand.prompt();
    }
}

Command Command::_currentCommand;
SimpleCommand * Command::_currentSimpleCommand;

int yyparse(void);

main()
{
	signal(SIGINT, disp);
	Command::_currentCommand.prompt();
	struct sigaction signalAction;
	signalAction.sa_handler = killzombie;	
	sigemptyset(&signalAction.sa_mask);
	signalAction.sa_flags = SA_RESTART;
	int error = sigaction(SIGCHLD, &signalAction, NULL );

	if ( error ) 
	{
		perror( "sigaction" );
		exit( -1 );
	}
	yyparse();
}

