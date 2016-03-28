
/*
 *
 * CS-252 Fall 2013
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <string.h>
#include "y.tab.h"
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

extern "C" char * read_line();

int mygetc(FILE * f) {
static char *p;
char ch;
if (!isatty(0)) {
        // stdin is not a tty. Call real get
	return getc(f);
}
        // stdin is a tty. Call our read_line.
 if (p==NULL || *p == 0) {
	char * s = read_line();
	p = s;
}

ch = *p;
p++;
return ch;
}

#undef getc
#define getc(f) mygetc(f)


static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
    unput(c);
}

%}

%%

\n 	{
		return NEWLINE;
	}

[ \t] 	{
		/* Discard spaces and tabs */
     	}	

">&"    {
		return GREATAMP;

	}

">" 	{
		return GREAT;
	}

">>"	{
		return GREATGREAT;
	}

">>&"	{
		return GREATGREATAMP;
	}

"<"	{
		return LESSER;
	}

"|"	{
		return PIPE;
	}

"&"	{
		return AMP;
	}

\"[^\n\"]*\" {
		/*allows quotes*/
		int start = 1;
		int end = 1;

		end = strlen(yytext)-1;

		char *stringer = (char*)calloc(end+1, sizeof(char));
		strncpy(stringer, yytext+start, end-1);
		yylval.string_val = strdup(stringer);
		return WORD;
	}

`[^\n`]*` {
		char buff1[1024];
		/*allows backticks*/
		char checker[1024];
		int start = 0;
		int end = 0;
		while(yytext[start] != '\0'){
			if(yytext[start] == '`') {
				start++;
			}
			else {
				checker[end] = yytext[start];
				end++;
				start++;
			}
			checker[end] = '\n';
			strcat(checker, "exit\n");
		}

		int defin = dup(0);	
		int defout = dup(1);
		
		int childp[2];
		int parentp[2];

		if(pipe(childp) < 0) {
			perror("child pipe");
			exit(1);
		}
		if(pipe(parentp) < 0) {
			perror("parent pipe");
			exit(1);
		}

		dup2(childp[0], 0);
		dup2(parentp[1], 1);
		close(childp[0]);
		close(parentp[1]);
	
	
		int forker = fork();
		
		if(forker < 0){
			perror("fork");
			exit(0);
		}
		if(forker == 0){ //check for child
			dup2(childp[1],1);
			close(childp[1]);
			dup2(parentp[0], 0);
			close(parentp[0]);
		
		//running the subshell
			char* arg[2];
			arg[0] =(char *) getenv("_");
			arg[1] = NULL;
			execvp(arg[0], arg);
		}
			else {
				for(start = 0; start < strlen(checker); start++){
					write(1, checker+start, 1);
				}
				dup2(defout, 1);
				close(defout);

				close(childp[0]);
				close(childp[1]);
				close(parentp[0]);
				close(parentp[1]);

				char check;
				start = 0;
				while (read(0, &check, 1) != 0){
					if(check == '\n') {
						buff1[start] = ' ';
					}
					else {
						buff1[start] = check;
					}
					start++;
				}

				buff1[start] = '\0';
				dup2(defin, 0);
				close(defin);
			}
			waitpid(forker, NULL, 0);
			start = 0;

			while(start < strlen(buff1)){
				unput(buff1[strlen(buff1) - 1 - start]);
				start++;
			}
			yylval.string_val = strdup(strdup(checker));
	}

	

[^ \t\n]*\\+[^ \t\n]*  {
		/* Assume that file names have only alpha chars */
		int start = 1;
		int end = 1;
		int j = 0;
		
		end = strlen(yytext)-1;
	        char *stringer = (char*)malloc(sizeof(char) * end);
		if(yytext[0] == '"' && yytext[end] == '"'){
			strncpy(stringer, yytext+start, end-1);
		}
		else{
			strcpy(stringer, yytext);
		}

		char *buff = (char*)malloc(sizeof(char) * end);
		for(int i =0; i < strlen(stringer); i++) {
			if(stringer[i] == '\\') {
				buff[j] =  stringer[i+1];
				i++;
				j++;
			}
			else{
				buff[j] = stringer[i];
				j++;
			}
		}
		buff[j] = '\0';
		yylval.string_val = strdup(buff);
		return WORD;		
	}

[^ \t\n\|<>\&][^ \t\n\|<>\&]* {
		yylval.string_val = strdup(yytext);
		return WORD;
}

