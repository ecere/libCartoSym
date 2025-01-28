public import IMPORT_STATIC "ecere"

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

   // Multi char symbols
   notEqual = 256,   // <>
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
   notBetween, // Handled as separate token?
   notLike,
   notIn,
   ;
   ///////////////

   property char { }

   property bool isUnaryOperator
   {
      get
      {
         return this == '-' || this == not;
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
   { "DIV", intDivide }
] };

static CQL2TokenType matchToken(const String text)
{
   CQL2TokenType type = identifier;
   MapIterator<CIString, CQL2TokenType> it { map = cql2StringTokens };

   if(it.Index(text, false))
      type = it.data;
   return type;
}

class CQL2Token
{
public:
   property CQL2TokenType type { get { return this ? type : 0; } };
private:
   CQL2TokenType type;
   String text;

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
   number
};

public class CQL2OutputOptions : uint
{
public:
   bool reserved:1;
   bool dbgOneLiner:1;
   bool skipEmptyBlocks:1;
   bool skipImpliedID:1;
   bool multiLineInstance:1;
}

public struct CQL2CodePosition
{
public:
   int line, col, pos;
   int included;
};

#define LEXER_TEXT_BUFFER_SIZE   4096

// Based on NameStartChar rule from https://www.w3.org/TR/REC-xml/#sec-common-syn
bool isValidCQL2IdStart(unichar ch)
{
   return ch == ':' || ch == '_' ||
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
bool isValidCQL2IdChar(unichar ch)
{
   return isValidCQL2IdStart(ch) ||
      ch == '.' || ch == '·' /*0xB7*/ ||
      (ch >= '0' && ch <= '9') ||
      (ch >= 0x0300 && ch <= 0x036F) ||
      (ch >= 0x203F && ch <= 0x2040);
}

public class CQL2Lexer
{
   /*const */String input;

   CQL2TokenType type; type = none;
   CQL2Token token, nextToken;
   Array<CQL2Token> tokenStack { minAllocSize = 256 };
   int stackPos;
   CQL2CodePosition pos;
   char text[LEXER_TEXT_BUFFER_SIZE]; // FIXME: dynamic size
   int wktContext;

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
         char * exponent = strchrmax(word, 'e', wordLen);
         if(!exponent) exponent = strchrmax(word, 'E', wordLen);
         isReal = exponent != null;
      }
      if(isReal)
         strtod(word, &s);
      else
         strtol(word, &s, 10);
      if(s && s != word)
      {
         valid = true;

         // No suffixes supported in CQL
         if(s[0] == '_' || isalpha(s[0]))
            valid = false;

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
            wordLen = s - word;
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

         text[0] = 0;
         while(type == none)
         {
            int nb;
            unichar ch = UTF8GetChar(input + pos.pos, &nb);
            bool advanceChar = ch ? true : false;
            switch(lexingState)
            {
               case string:
                  if(!ch || (ch == '\'' && !escaped && input[pos.pos+1] != '\''))
                  {
                     int copySize = Min(pos.pos - start+2, LEXER_TEXT_BUFFER_SIZE-1);
                     strncpy(text, input + start-1, copySize);
                     text[copySize] = 0;
                     type = stringLiteral;
                  }
                  else // TODO: double '' is the escape char for literals, except in like-predicate
                     escaped = ch == '\\' || ch == '\'';
                  break;
               case identifier:
               {
                  if((!doubleQuotedID || ch == '"') && !isValidCQL2IdChar(ch))
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
                           default: type = smaller;
                        }
                        break;
                     case '>':
                        switch(input[pos.pos+1])
                        {
                           case '=': type = greaterEqual, pos.pos++, pos.col++; break;
                           default: type = greater;
                        }
                        break;
                     case '+': type = plus; break;
                     case '-': type = minus; break;
                     case '*': type = multiply; break;
                     case '/': type = divide; break;
                     case '%': type = modulo; break; break;
                     case '^': type = power; break;
                     case '\'':
                        start = pos.pos+1;
                        lexingState = string;
                        break;
                     case ',': case '(': case ')': case '[': case ']': case '\0':
                        type = (char)ch;
                        break;
                     default:
                        start = pos.pos;
                        if(ch == '.' || isdigit(ch))
                           lexingState = number;
                        else if(ch == '"' || isValidCQL2IdStart(ch))
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

   CQL2Token peekToken()
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
               this.type = none;
            }
         }
      }
      return nextToken;
   }

   CQL2Token readToken()
   {
      if(!nextToken) peekToken();
      delete token;
      token = nextToken;
      nextToken = null;
      return token;
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
      type = none;
   }
};
