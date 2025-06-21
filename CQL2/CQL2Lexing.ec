public import IMPORT_STATIC "ecrt"

public enum CQL2TokenType
{
   // Core Tokens
   none = 9999,
   syntaxError = 3000,
   lexingError = 2000,
   identifier = 1000,
   constant,
   stringLiteral,

   endOfInput = 0, // FIXME (enum values with escaped char) '\0',

   // Comparison
   smaller = '<',
   greater = '>',

   equal = '=',

   // Arithmetic
   plus = '+',
   minus = '-',
   multiply = '*',
   divide = '/',
   power = '^',
   modulo = '%',

   /////////////////////////////////
   comma = ',',

   openParenthesis = '(',
   closeParenthesis = ')',

   openBracket = '[',
   closeBracket = ']',

   // Non-standard CQL2
   notAlt = '!',       //  Alternative logical Not

   question = '?', // Ternary conditional If
   colon = ':',    // Ternary conditional Else; CartoSym property assignment

   orAlt = '|',   // Logical Or
   andAlt = '&',  // Logical And

   openCurly = '{',  // CartoSym-CSS Instances, Styling Rule blocks
   closeCurly = '}',

   semiColon = ';', // End of property assignment
   dot = '.',       // CartoSym-CSS Style Metadata; Member operator

   // Text operators -- REVIEW: Will this be functions instead?
   stringContains = '~',
   stringEndsWith = '$',

   // Multi char symbols
   notEqual = 256,   // <> (or != alternative)
   smallerEqual,     // <=
   greaterEqual,     // >=
   not,
   or,
   and,
   is,
   in,
   between,
   like,
   intDivide,
   notBetween, // REVIEW: Handled as separate token?
   notLike,
   notIn,

   // Non-standard CQL2
   // Text Comparison
   stringContains,
   stringStartsWith,
   stringEndsWith,
   stringNotContains,
   stringNotStartsW,
   stringNotEndsW,

   // Bitwise Arithmetic
   bitAnd,
   bitOr,
   bitXor,
   bitNot,
   lShift,
   rShift,

   addAssign, // += // REVIEW: Do we have this in CartoSym-CSS?

   ;
   ///////////////

   property char { }

   property bool isUnaryOperator
   {
      get
      {
         return this == '-' || this == not || this == notAlt || this == bitNot;
      }
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      if(this < 256)
         out.Print((char)this);
      else
      {
         static bool initialized = false;
         if(!initialized)
         {
            initialized = true;
            for(r : cql2StringTokens)
               tokenStrings[r] = &r;
         }
         out.Print(tokenStrings[this]);
      }
   }

   public String toString(CQL2OutputOptions o)
   {
      TempFile f { };
      String s;
      print(f, 0, o);
      f.Putc(0);
      s = (String)f.StealBuffer();
      delete f;
      return s;
   }
};

static const String tokenStrings[CQL2TokenType];
/*static */Map<CIString, CQL2TokenType> cql2StringTokens
{ [
   { "<=", smallerEqual },
   { ">=", greaterEqual },
   { "IS", is },
   { "<>", notEqual },
   { "NOT", not },
   { "AND", and },
   { "OR", or },
   { "IN", in },
   { "NOT IN", notIn },
   { "BETWEEN", between },
   { "NOT BETWEEN", notBetween },
   { "LIKE", like },
   { "NOT LIKE", notLike },
   { "DIV", intDivide },

   // Non-standard CQL2
   /*
   { "==", equal },
   { "!=", notEqual },
   { "&&", and },
   { "||", or },
   */
   { "+=", addAssign }, // REVIEW: Will this be used in CartoSym-CSS?

   // Text operators -- REVIEW: Will this be functions instead?
   { "^^", stringStartsWith },
   { "!~", stringNotContains },
   { "!^", stringNotStartsW },
   { "!$", stringNotEndsW },

   // Bitwise operators
   { "bitand", bitAnd },
   { "bitor", bitOr },
   { "bitxor", bitXor },
   { "bitnot", bitNot },
   { "<<", lShift },
   { ">>", rShift }
] };

static CQL2TokenType matchToken(const String text)
{
   CQL2TokenType type = identifier;
   MapIterator<CIString, CQL2TokenType> it { map = cql2StringTokens };

   if(it.Index(text, false))
      type = it.data;
   return type;
}

public class CQL2Token
{
public:
   property CQL2TokenType type { get { return this ? type : 0; } };
private:
   CQL2TokenType type;
   public String text;

   ~CQL2Token()
   {
      delete text;
   }
}

static enum CQL2LexingState
{
   none,
   string,
   identifier,
   number,

   // For CartoSym-CSS:
   singleLineComment,
   multiLineComment
};

public class CQL2OutputOptions : uint
{
public:
   bool reserved:1;
   bool dbgOneLiner:1;
   bool skipEmptyBlocks:1;
   bool skipImpliedID:1;
   bool multiLineInstance:1;
   bool strictCQL2:1;
}

public struct CQL2CodePosition
{
public:
   int line, col, pos;
   int included;
};

#define LEXER_TEXT_BUFFER_SIZE   4096

// Based on NameStartChar rule from https://www.w3.org/TR/REC-xml/#sec-common-syn
bool isValidCQL2IdStart(unichar ch, bool allowColon)   // Strict CQL2 allows :, CartoSym-CSS disallows : (must be quoted)
{
   return (allowColon && ch == ':') || ch == '_' ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= 'a' && ch <= 'z') ||
      (ch >=    0xC0 && ch <=   0xD6) || // Skip ×
      (ch >=    0xD8 && ch <=   0xF6) || // Skip ÷
      (ch >=    0xF8 && ch <=  0x2FF) ||
      (ch >=   0x370 && ch <=  0x37D) || // Skip ; odd semicolon
      (ch >=   0x37F && ch <= 0x1FFF) ||
      (ch >=  0x200C && ch <= 0x200D) ||
      (ch >=  0x2070 && ch <= 0x218F) ||
      (ch >=  0x2C00 && ch <= 0x2FEF) ||
      (ch >=  0x3001 && ch <= 0xD7FF) ||
      (ch >=  0xF900 && ch <= 0xFDCF) ||
      (ch >=  0xFDF0 && ch <= 0xFFFD) ||
      (ch >= 0x10000 && ch <= 0xEFFFF);
}

// Based on NameChar rule from https://www.w3.org/TR/REC-xml/#sec-common-syn
bool isValidCQL2IdChar(unichar ch, bool allowColon)
{
   return isValidCQL2IdStart(ch, allowColon) ||
      ch == '.' || ch == '·' /*0xB7*/ ||
      (ch >= '0' && ch <= '9') ||
      (ch >= 0x0300 && ch <= 0x036F) ||
      (ch >= 0x203F && ch <= 0x2040);
}

public class CQL2Lexer
{
   /*const */String input;

   public CQL2TokenType type; type = none;   // REVIEW:  Can we use token.type from readToken() ?
   CQL2Token token;
   public CQL2Token nextToken;      // REVIEW:  probably doesn't need to be public if we use peekToken()
   Array<CQL2Token> tokenStack { minAllocSize = 256 };
   int ambiguous, stackPos;
   public CQL2CodePosition pos;  // REVIEW: Does this need to be public?
   char text[LEXER_TEXT_BUFFER_SIZE]; // FIXME: dynamic size
   int wktContext;
   bool strictCQL2;

   ~CQL2Lexer()
   {
      delete input;
      tokenStack.Free();
      delete nextToken;
      delete token;
   }

   bool readConstant(const char * word, int wordLen)
   {
      bool valid = false;
      const char * dot = word[wordLen] == '.' ? word + wordLen : (word[0] == '.' && (word == input || word[-1] == '-' || isspace(word[-1])) ? word : null);
      bool isReal = dot != null;
      char * s = null;
      if(dot)
         isReal = true;
      else
      {
         char * exponent;
         bool isHex = !strictCQL2 && (word[0] == '#' || (word[0] == '0' && (word[1] == 'x' || word[1] == 'X')));
         if(isHex)
         {
            exponent = strchrmax(word, 'p', wordLen);
            if(!exponent) exponent = strchrmax(word, 'P', wordLen);
         }
         else
         {
            exponent = strchrmax(word, 'e', wordLen);
            if(!exponent) exponent = strchrmax(word, 'E', wordLen);
         }
         isReal = exponent != null;
      }
      if(isReal)
         strtod(word, &s);      // strtod() seems to break on hex floats (e.g. 0x23e3p12, 0x1.fp3)
      else
         strtoll(word[0] == '#' ? word + 1 : word, &s, strictCQL2 ? 10 : word[0] == '#' ? 16 : 0);
      if(s && s != word)
      {
         // Check suffixes
         char ch;
         int i = 0;
         int gotF = 0, gotL = 0, gotU = 0, gotI = 0;
         valid = true;

         if(strictCQL2)
         {
            // No suffixes supported in CQL
            if(s[0] == '_' || isalpha(s[0]))
               valid = false;
         }
         else
         {
            for(i = 0; valid && i < 5 && (ch = s[i]) && (isalnum(ch) || ch == '_'); i++)
            {
               switch(ch)
               {
                  case 'f': case 'F': gotF++; if(gotF > 1 || !isReal) valid = false; break;
                  case 'l': case 'L':
                     gotL++;
                     if(gotL > 2 || (isReal && (gotL == 2 || gotF)) || (gotL == 2 && (s[i-1] != ch)))
                     valid = false;
                     break;
                  case 'u': case 'U': gotU++; if(gotU > 1 || isReal) valid = false; break;
                  case 'i': case 'I': case 'j': case 'J': gotI++; if(gotI > 1) valid = false; break;
                  default: valid = false;
               }
            }
         }

         // Check for too many decimal points
         if(s[0] == '.' && isdigit(s[1]))
         {
            while(s[0] == '.' && isdigit(s[1]))
            {
               wordLen = s - word;
               strtod(s, &s);
            }
            wordLen = s - word;
         }
         else if(valid)
            wordLen = s + i - word;
      }
      strncpy(text, word, wordLen);
      text[wordLen] = 0;
      {
         int newPos = ((int)(word - input)) + wordLen;
         pos.col += newPos - pos.pos;
         pos.pos = newPos;
      }
      return valid;
   }

   CQL2TokenType prepareNextToken()
   {
      if(type == none)
      {
         const String input = this.input;
         CQL2CodePosition pos = this.pos;
         int start = 0;
         CQL2TokenType type = none;
         bool escaped = false;
         CQL2LexingState lexingState = none;
         bool doubleQuotedID = false;
         bool continuingString = false;

         text[0] = 0;
         while(type == none)
         {
            int nb;
            unichar ch = UTF8GetChar(input + pos.pos, &nb);
            bool advanceChar = ch ? true : false;
            switch(lexingState)
            {
               case string:
                  if(!ch || (ch == '\'' && !continuingString && !escaped && input[pos.pos+1] != '\''))
                  {
                     bool isContinued = false;
                     if(!strictCQL2)
                     {
                        const char * n = input + pos.pos+1;
                        CQL2CodePosition np { pos.line, pos.col + 1, pos.pos + 1 };
                        while(*n == ' ' || *n == '\t' || *n == '\r' || *n == '\n')
                        {
                           if(*n == '\r');
                           else if(*n == '\n') np.line++, np.col = 0;
                           else
                              np.col++, np.pos++, pos.col++;
                           n++;
                        }
                        if(*n == '\'')
                        {
                           isContinued = true, pos = np;
                           continuingString = true;
                        }
                     }
                     if(!isContinued)
                     {
                        int copySize = Min(pos.pos - start+2, LEXER_TEXT_BUFFER_SIZE-1);
                        strncpy(text, input + start-1, copySize);
                        text[copySize] = 0;
                        type = /*isChar ? constant : */stringLiteral;
                     }
                  }
                  else // TODO: double '' is the escape char for literals, except in like-predicate
                  {
                     escaped = ch == '\\' || ch == '\'';
                     continuingString = false;
                  }
                  break;
               case identifier:
               {
                  if((!doubleQuotedID || ch == '"') && !isValidCQL2IdChar(ch, strictCQL2))
                  {
                     int len = Min(pos.pos - start, sizeof(this.text)-1);
                     if(ch == '"')
                        start++, len --;
                     else
                        advanceChar = false;
                     strncpy(this.text, input + start, len);
                     this.text[len] = 0;
                     type = doubleQuotedID ? identifier : matchToken(text);
                     doubleQuotedID = false;
                  }
                  break;
               }
               case number:
               {
                  if(!isalnum(ch) && ch != '_')
                  {
                     readConstant(input + start, pos.pos - start);
                     pos = this.pos;
                     type = CQL2TokenType::constant;
                     advanceChar = false;
                  }
                  break;
               }
               case multiLineComment:
                  if(ch == '*' && input[pos.pos+1] == '/')
                  {
                     pos.pos++, pos.col++;
                     lexingState = 0;
                  }
                  break;
               case singleLineComment:
                  if(ch == '\n' && (!pos.pos || input[pos.pos-1] != '\\'))
                  {
                     lexingState = 0;
                     pos.line++, pos.col = 0;
                  }
                  break;
               default:
               {
                  switch(ch)
                  {
                     case ' ': case '\t': case '\r': case '\n':
                        if(ch == '\n')
                           pos.line++, pos.col = 0;
                        break;
                     case '=':
                        if(input[pos.pos+1] == '=')
                           type = equal, pos.pos++, pos.col++;
                        else
                           type = equal;
                        break;
                     case '<':
                        switch(input[pos.pos+1])
                        {
                           case '=': type = smallerEqual, pos.pos++, pos.col++; break;
                           case '>': type = notEqual, pos.pos++, pos.col++; break;
                           case '<': type = lShift, pos.pos++, pos.col++; break;
                           default: type = smaller;
                        }
                        break;
                     case '>':
                        switch(input[pos.pos+1])
                        {
                           case '=': type = greaterEqual, pos.pos++, pos.col++; break;
                           case '>': type = rShift, pos.pos++, pos.col++; break;
                           default: type = greater;
                        }
                        break;
                     case '~': if(!strictCQL2) { type = stringContains; break; }
                     case '^':
                        switch(input[pos.pos+1])
                        {
                           // REVIEW: += in CartoSym-CSS ?
                           case '^': if(!strictCQL2) { type = stringStartsWith, pos.pos++, pos.col++; break; }
                           default: type = power;
                        }
                        break;
                     case '$': if(!strictCQL2) { type = stringEndsWith; break; }
                     case '!':
                        if(!strictCQL2)
                        {
                           char next = input[pos.pos+1];
                                if(next == '=') pos.pos++, pos.col++, type = notEqual;
                           else if(next == '~') pos.pos++, pos.col++, type = stringNotContains;
                           else if(next == '^') pos.pos++, pos.col++, type = stringNotStartsW;
                           else if(next == '$') pos.pos++, pos.col++, type = stringNotEndsW;
                           else
                              type = not;
                           break;
                        }
                     case '+':
                        switch(input[pos.pos+1])
                        {
                           // REVIEW: += in CartoSym-CSS ?
                           case '=': if(!strictCQL2) { type = addAssign, pos.pos++, pos.col++; break; }
                           default: type = plus;
                        }
                        break;
                     case '-': type = minus; break;
                     case '*': type = multiply; break;
                     case '/':
                        switch(input[pos.pos+1])
                        {
                           case '/': if(!strictCQL2) { lexingState = singleLineComment, start = pos.pos, pos.pos++, pos.col++; break; }
                           case '*': if(!strictCQL2) { lexingState = multiLineComment, start = pos.pos, pos.pos++, pos.col++; break; }
                           default: type = divide;
                        }
                        break;
                     case '%': type = modulo; break;
                     case '|':
                        if(!strictCQL2)
                        {
                           switch(input[pos.pos+1])
                           {
                              case '|': type = or, pos.pos++, pos.col++; break;
                              default: type = or; break;
                           }
                           break;
                        }
                     case '&':
                        if(!strictCQL2)
                        {
                           switch(input[pos.pos+1])
                           {
                              case '&': type = and, pos.pos++, pos.col++; break;
                              default: type = and;
                           }
                        }
                        break;
                     case '\'':
                        start = pos.pos+1;
                        lexingState = string;
                        break;
                     case ',': case '(': case ')': case '[': case ']': case '\0':
                        type = (char)ch;
                        break;
                     case '?': case ';': case '{': case '}': case ':': case '.':
                        if(!strictCQL2)
                        {
                           type = (CQL2TokenType)ch;
                           break;
                        }
                     default:
                        start = pos.pos;
                        if(ch == '.' || isdigit(ch) || ch == '#')
                           lexingState = number;
                        else if(ch == '"' || isValidCQL2IdStart(ch, strictCQL2))
                        {
                           if(ch == '"')
                              doubleQuotedID = true;
                           lexingState = identifier;
                        }
                        else
                        {
                           type = lexingError;
#ifdef _DEBUG
                           PrintLn("Invalid character: ", ch, " at line: ", pos.line, ", col: ", pos.col);
#endif
                        }
                        break;
                  }
                  break;
               }
            }
            if(advanceChar) pos.col++, pos.pos += nb;
            if(!ch)
            {
               if(lexingState == string)
               {
                  type = lexingError;
#ifdef _DEBUG
                  PrintLn("Unterminated string literal at line: ", pos.line, ", col: ", pos.col);
#endif
               }
               break;
            }
         }
         this.pos = pos;
         this.type = type;
      }
      return type;
   }

   public CQL2Token peekToken()
   {
      if(!nextToken)
      {
         if(stackPos < tokenStack.count)
         {
            nextToken = tokenStack[stackPos++];
            incref nextToken;
            if(stackPos == tokenStack.count)
            {
               tokenStack.Free();
               stackPos = 0;
            }
         }
         else
         {
            CQL2TokenType type = prepareNextToken();
            if(type != endOfInput)
            {
               nextToken = { _refCount = 1, type = type, text = CopyString(text) };
               if(ambiguous)
               {
                  stackPos++;
                  tokenStack.Add(nextToken);
                  incref nextToken;
               }
               this.type = none;
            }
         }
      }
      return nextToken;
   }

   public CQL2Token readToken()
   {
      if(!nextToken) peekToken();
      delete token;
      token = nextToken;
      nextToken = null;
      return token;
   }

   public int pushAmbiguity()
   {
      if(!ambiguous && nextToken && stackPos == tokenStack.count)
      {
         stackPos++;
         tokenStack.Add(nextToken);
         incref nextToken;
      }
      ambiguous++;
      return stackPos - (nextToken ? 1 : 0);
   }

   public void clearAmbiguity()
   {
      if(!--ambiguous && stackPos > 0)
      {
         int i;
         for(i = 0; i < stackPos; i++)
            delete tokenStack[i];
         if(tokenStack.size > stackPos)
            memmove(tokenStack.array, tokenStack.array + stackPos, (tokenStack.size - stackPos) * sizeof(CQL2Token));
         tokenStack.size -= stackPos;
         stackPos = 0;
      }
   }

   public void popAmbiguity(int i)
   {
      delete token;
      delete nextToken;

      stackPos = i;
      clearAmbiguity();
      token = null;
      nextToken = null;
   }

   void lexAll(File out)
   {
      while(readToken())
      {
         switch(token.type)
         {
            case identifier:
            case stringLiteral:
            case constant:
               out.PrintLn(token.type, " (", token.text, ")");
               break;
            default:
               if(token.type < 256)
                  out.PrintLn((char)token.type);
               else
                  out.PrintLn(token.type);
               break;
         }
      }
   }

   public void initFile(File f)
   {
      uint64 len = f.GetSize();
      char * data = new char[len+1];
      f.Read(data, 1, len);
      data[len] = 0;
      delete (char *)input;
      input = data;
      pos = { 1, 1, 0 };

      tokenStack.Free();

      delete token;
      delete nextToken;
      tokenStack.size = 0;
      stackPos = 0;
      ambiguous = 0;
      type = none;
   }
   public void initString(const String string)
   {
      delete (char *)input;
      input = CopyString(string); // TODO: Flag whether to free to avoid copy?
      pos = { 1, 1, 0 };

      tokenStack.Free();

      delete token;
      delete nextToken;
      tokenStack.size = 0;
      stackPos = 0;
      ambiguous = 0;
      type = none;
   }
};
