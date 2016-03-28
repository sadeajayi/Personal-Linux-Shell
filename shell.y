/*
 * CS-252 Spring 2013
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%token	<string_val> WORD

%token 	NOTOKEN GREAT NEWLINE AMP GREATGREAT LESSER GREATGREATAMP GREATAMP PIPE 
%union	{
		char   *string_val;
	}

%{
//#define yylex yylex
#include <string.h>
#include <stdio.h>
#include "command.h"
#include <stdlib.h>
void yyerror(const char * s);
void expandWildcard(char *, char *);
int yylex();

%}

%%

goal:	
	commands
	;

commands: 
	command
	| commands command 
	;

command: simple_command
        ;

simple_command:	
	pipe_list iomodifiers ampersand NEWLINE {
		//printf("   Yacc: Execute command\n"); 
		Command::_currentCommand.execute();
	}
	| NEWLINE 
	| error NEWLINE { yyerrok; }
	;

pipe_list:
	pipe_list PIPE command_and_args
	| command_and_args
	;

iomodifiers:
	/*empty*/	
	| iomodifiers iomodifier_opt
	;

ampersand:
	AMP {
		Command::_currentCommand._background = 1;
	}
	|
	;

command_and_args:
	command_word arg_list {
		Command::_currentCommand.
			insertSimpleCommand( Command::_currentSimpleCommand );
	}
	;

arg_list:
	arg_list argument
	| /* can be empty */
	;

argument:
	WORD {
			if (strchr($1, '*') == NULL && strchr($1, '?') == NULL) {
				Command::_currentSimpleCommand->insertArgument( $1 );
			}
			else {
				char * empty = (char*)malloc(1*sizeof(char));
				expandWildcard(empty, $1);
			}

			//printf("   Yacc: insert argument \"%s\"\n", $1);
			//Command::_currentSimpleCommand->insertArgument( $1 );
	}
	;

command_word:
	WORD {
              // printf("   Yacc: insert command \"%s\"\n", $1);    
	       Command::_currentSimpleCommand = new SimpleCommand();
	       Command::_currentSimpleCommand->insertArgument( $1 );
	}
	;

iomodifier_opt:
	GREAT WORD {
		//printf("   Yacc: insert output \"%s\"\n", $2);
		if(Command::_currentCommand._outFile) {
			printf("Ambiguous output redirect");
		}
		Command::_currentCommand._outFile = $2;
	} 
	|
	LESSER WORD {
		//printf("    Yacc: insert input \"%s\"\n", $2);
		Command::_currentCommand._inputFile = $2;
	}
	|
	GREATAMP WORD {
		if(Command::_currentCommand._outFile){
	        	printf("Ambiguous output redirect");
                }
		Command::_currentCommand._outFile = $2;
		Command::_currentCommand._errFile = $2;

		//printf("    Yacc: insert        ");
	}
	|
	GREATGREAT WORD {
		if(Command::_currentCommand._outFile){
			printf("Ambiguous output redirect \n");
		}
		Command::_currentCommand._outFile = $2;
		Command::_currentCommand._appender = 1;
	}
	|
	GREATGREATAMP WORD {
		if(Command::_currentCommand._outFile){
			printf("Ambiguous output redirect");
                }
		Command::_currentCommand._outFile = $2;
		Command::_currentCommand._appender = 1;
		Command::_currentCommand._errFile = $2;
	}
	;
%%

#include <string.h>
#include <stdlib.h>
#include <regex.h>
#include <stdio.h>
#include <sys/types.h>
#include <dirent.h>
#include <unistd.h>
#include <signal.h>


void expandWildcard(char *prefix, char *suffix) {

	if(suffix[0]== 0){
		Command::_currentSimpleCommand->insertArgument(strdup(++prefix));
		return;
	}
	
	char * stringer = strchr(suffix, '/');
	char * component = (char *) malloc (1024 * sizeof(char));
	
	if (stringer!=NULL) { // Copy up to the first "/"
		strncpy(component,suffix, stringer-suffix);
		suffix = stringer + 1;
	}
	else { // Last part of path. Copy whole thing.
		strcpy(component, suffix);
		suffix = suffix + strlen(suffix);
	}

	char newPrefix[1024];

	if (strchr(component, '*') == NULL && strchr(component, '?') == NULL) {
		sprintf(newPrefix, "%s/%s", prefix, component);
		expandWildcard(newPrefix, suffix); 
		return; 
	}

	char * reg = (char *) malloc(2*strlen(component)+10);
	char * a = component;
	char * r = reg;
	*r = '^'; r++;
	while (*a) {
		if(*a == '*') { *r = '.'; r++; *r = '*'; r++; }
		else if (*a == '?') { *r = '.'; r++; }
		else if (*a == '.') { *r = '\\'; r++; *r = '.'; r++; }
		else { *r = *a; r++; }
		a++;
	}
	*r='$'; r++; *r='\0';
	
	//compile regular expression.
//	char * expbuf = regcomp(reg,0);
//	if (expbuf == NULL) {
//		perror("regcomp");
//		return;
//	}
	regex_t temp;
	int regSuccess;

	regSuccess = regcomp(&temp, reg, 0);
	if (regSuccess) {
		perror("compiling");
		exit(1);
	}

	struct dirent ** dirlist;
	int counter;
	//DIR * dir = opendir(".");
	//if(dir == NULL) {
	//	perror("opendir");
	//	return;
	//}
	if (prefix[0] == 0) {
		counter = scandir(".", &dirlist,0,alphasort);
	}
	else {
		counter = scandir(prefix, &dirlist,0,alphasort);
	}
	
	if (counter < 0) { 
		return; 
	}
	else {
		int i = 0;
		while (i < counter) {
			regSuccess = regexec(&temp, dirlist[i]->d_name, 0, NULL, 0);
			if (!regSuccess) {
				if (component[0] == '.') {
					sprintf(newPrefix, "%s/%s", prefix, dirlist[i]->d_name);
					expandWildcard(newPrefix, suffix);
				}
				else {
					if (dirlist[i]->d_name[0] == '.') {}
					else {
						sprintf(newPrefix, "%s/%s", prefix, dirlist[i]->d_name);
						expandWildcard(newPrefix, suffix);
					}
				}
			}
			i++;
		}
	}	
	return;
}

void
yyerror(const char * s)
{
	fprintf(stderr,"%s", s);
}

#if 0
main()
{
	yyparse();
}
#endif
