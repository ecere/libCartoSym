public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "SFGeometry"
public import IMPORT_STATIC "SFCollections"  // For TemporalOptions

private:

import "Colors"      // FIXME: Here for now, but should only be in CartoSym
import "CQL2Lexing"
import "CQL2Node"
import "CQL2Tools"
import "CQL2Evaluator"
import "CQL2Internalization"   // for convertToInternalCQL2()

default:
extern int __eCVMethodID_class_OnGetDataFromString;
extern int __eCVMethodID_class_OnGetString;
extern int __eCVMethodID_class_OnCopy;
extern int __eCVMethodID_class_OnFree;
static __attribute__((unused)) void dummy() { int a = 0; a.OnGetDataFromString(null); a.OnGetString(0,0,0); }
private:

#define BINARY(o, name, m, t)                                        \
   static bool name(FieldValue value, const FieldValue val1, const FieldValue val2)   \
   {                                                                    \
      value.m = val1.m o val2.m;                               \
      value.type = { type = t };                                     \
      return true;                                                \
   }

#define BINARY_DIVIDEINT(o, name, m, t) \
   static bool name(FieldValue value, const FieldValue val1, const FieldValue val2)   \
   {                                                                 \
      value.m = (val2.m ? ((val1.m o val2.m)) : 0);             \
      value.type = { type = t };                                     \
      return true;                                                \
   }


#define BINARY_LOGICAL(o, name, m, t)                                        \
   static bool name(FieldValue value, const FieldValue val1, const FieldValue val2)   \
   {                                                                    \
      value.i = val1.m o val2.m;                               \
      value.type = { type = integer };                                     \
      return true;                                                \
   }

#define UNARY(o, name, m, t) \
   static bool name(FieldValue value, const FieldValue val1)                \
   {                                                              \
      value.m = (o val1.m);                                   \
      value.type = { type = t };                                     \
      return true;                                                \
   }

#define UNARY_LOGICAL(o, name, m, t) \
   static bool name(FieldValue value, const FieldValue val1)                \
   {                                                              \
      value.i = (o val1.m);                                   \
      value.type = { type = integer };                                     \
      return true;                                                \
   }


#define OPERATOR_ALL(macro, o, name) \
   macro(o, integer##name, i, integer) \
   macro(o, text##name, s, text) \
   macro(o, real##name, r, real)

#define OPERATOR_NUMERIC(macro, o, name) \
   macro(o, integer##name, i, integer) \
   macro(o, real##name, r, real)

#define OPERATOR_INT(macro, o, name) \
   macro(o, integer##name, i, integer)

#define OPERATOR_REAL(macro, o, name) \
   macro(o, real##name, r, real)

#define OPERATOR_TEXT(macro, o, name) \
   macro(o, text##name, s, text)

#define OPERATOR_TABLE_INT(type) \
    { type##Add, type##Sub, type##Mul, type##Div, type##DivInt, type##Mod, \
                          type##Neg, \
                          type##Not, \
                          type##Equ, type##Nqu, \
                          type##And, type##Or, \
                          type##Grt, type##Sma, type##GrtEqu, type##SmaEqu, \
                          null, null, null, null, null, null, \
                          type##BitAnd, type##BitOr, type##BitXor, type##LShift, type##RShift, type##BitNot \
                        }

#define OPERATOR_TABLE_REAL(type) \
    { type##Add, type##Sub, type##Mul, type##Div, type##DivInt, type##Mod, \
                          type##Neg, \
                          type##Not, \
                          type##Equ, type##Nqu, \
                          type##And, type##Or, \
                          type##Grt, type##Sma, type##GrtEqu, type##SmaEqu, \
                          null, null, null, null, null, null, \
                          type##BitAnd, null /*type##BitOr*/, null /*type##BitXor*/, null /*type##LShift*/, null /*type##RShift*/, null /*type##BitNot*/ \
                        }


#define OPERATOR_TABLE_TEXT(type) \
    { type##Add, null, null, null, null, null, null,  \
                          type##Not, \
                          type##Equ, type##Nqu, \
                          type##And, type##Or, \
                          type##Grt, type##Sma, type##GrtEqu, type##SmaEqu,  \
                          type##Contains, type##StartsWith, type##EndsWith, \
                          type##DoesntContain, type##DoesntStartWith, type##DoesntEndWith, \
                          null, null, null, null, null, null \
                        }

#define OPERATOR_TABLE_EMPTY(type) \
    { null, null, null, null, null, null, null,  \
                          null, \
                          null, null, \
                          null, null, \
                          null, null, null, null, \
                          null, null, null, null, null, null,     \
                          null, null, null, null, null, null \
}

OpTable opTables[FieldType] =
{
   OPERATOR_TABLE_EMPTY(nil),
   OPERATOR_TABLE_INT(integer),
   OPERATOR_TABLE_REAL(real),
   OPERATOR_TABLE_TEXT(text)
};

public enum ComputeType { preprocessing, runtime, other };

public class InstanceMask : uint64 { bool bitMember:1:63; } // Just to force this to be a bit class...


public class ExpFlags : uint
{
public:
   bool resolved:1:0;
   bool invalid:1:5;
   bool isNotLiteral:1:7; // REVIEW: Do we really need this flag
};


void * copyList(List list, CQL2Node copy(CQL2Node))
{
   List<CQL2Node> result = null;
   if(list)
   {
      result = eInstance_New(list._class);
      for(l : list)
         result.Add(copy((CQL2Node)l));
   }
   return result;
}

Array<String> splitIdentifier(const String s)
{
   Array<String> values { };
   int i, start = 0;
   if(!strchr(s, '.'))
      values.Add(CopyString(s));
   else
   {
      for(i = 0; ; i++)
      {
         char ch = s[i];
         if(!ch || ch == '.')
         {
            int len = i - start;
            String temp = new char[len+1];
            memcpy(temp, s + start, len);
            temp[len] = 0;
            values.Add(temp);
            start = i + 1;
            if(!ch) break;
         }
      }
   }
   return values;
}

public CQL2Expression simplifyResolved(FieldValue val, CQL2Expression e)
{
   // Handling some conversions here...
   Class destType = e ? e.destType : null;

   if(!e) return null;

   if(destType && e.expType != destType)
   {
      if(destType == class(float) || destType == class(double))
         convertFieldValue(val, {real}, val);
      else if(destType == class(String))
         convertFieldValue(val, {text}, val);
      else if(destType == class(int64) || destType == class(int) || destType == class(uint64) || destType == class(uint))
         convertFieldValue(val, {integer}, val);
   }

   if(e._class == class(CQL2ExpBrackets) && ((CQL2ExpBrackets)e).list && ((CQL2ExpBrackets)e).list.list.count > 1)
      return e; // Do not simplify lists with more than one element
   else if(e._class == class(CQL2ExpConditional))
   {
      CQL2ExpConditional conditional = (CQL2ExpConditional)e;
      CQL2Expression ne = null;
      if(conditional.result)
      {
         CQL2Expression last = conditional.expList ? conditional.expList.lastIterator.data : null;
         if(last)
            ne = last, conditional.expList.TakeOut(last);
      }
      else
         ne = conditional.elseExp, conditional.elseExp = null;
      ne = simplifyResolved(val, ne);
      delete e;
      return ne;
   }
   else if(e._class != class(CQL2ExpString) && e._class != class(CQL2ExpConstant) && e._class != class(CQL2ExpInstance) && e._class != class(CQL2ExpArray))
   {
      CQL2Expression ne = (val.type.type == text) ? (val.s ? CQL2ExpString { string = CopyString(val.s) } :  CQL2ExpIdentifier { identifier = CQL2Identifier { string = CopyString("null") } })  : CQL2ExpConstant { constant = val };
      ne.destType = e.destType;
      ne.expType = e.expType;
      delete e;
      return ne;
   }
   else if(e._class == class(CQL2ExpInstance))
   {
      Class c = e.expType ? e.expType : e.destType;   // NOTE: At this point, expType should be set but is currently null?
      if(c && c.type == bitClass)
      {
         CQL2Expression ne = CQL2ExpConstant { constant = val };
         ne.destType = e.destType;
         ne.expType = e.expType;
         delete e;
         return ne;
      }
      else if(c && c == class(DateTime) && val.type.isDateTime)
      {
         CQL2Expression ne = CQL2ExpConstant { constant = val };
         ne.destType = e.destType;
         ne.expType = e.expType;
         delete e;
         return ne;
      }
   }
   return e;
}

public CQL2Expression parseCQL2Expression(const String string)
{
   CQL2Expression e = null;
   if(string)
   {
      CQL2Lexer lexer { };
      lexer.initString(string);
      e = CQL2Expression::parse(lexer);

      if(lexer.type == lexingError || (lexer.nextToken && lexer.nextToken.type != endOfInput))
      {
#ifdef _DEBUG
         if(lexer.type == lexingError)
            PrintLn("CQL2-Text/CartoSym-CSS Lexing Error at line ", lexer.pos.line, ", column ", lexer.pos.col);
         else
            PrintLn("CQL2-Text/CartoSym-CSS Syntax Error: Unexpected token ", lexer.nextToken.type,
               lexer.nextToken.text ? lexer.nextToken.text : "",
               " at line ", lexer.pos.line, ", column ", lexer.pos.col);
#endif
         delete e;
      }

      delete lexer;
   }
   return e;
}

static CQL2TokenType opPrec[][10] =
{
   { '^' },
   { '*', '/' , intDivide, '%' },
   { '+', '-' },
   { in },
   { lShift, rShift },
   { '<', '>', smallerEqual, greaterEqual },
   { equal, notEqual, is, like, stringStartsWith, stringNotStartsW, stringEndsWith, stringNotEndsW, stringContains, stringNotContains },
   { bitAnd },
   { bitOr },
   { bitNot },
   { bitXor },
   { and },
   { or, not /* for not between */, between }
};

static define numPrec = sizeof(opPrec) / sizeof(opPrec[0]);

public bool isLowerEqualPrecedence(CQL2TokenType opA, CQL2TokenType opB)
{
   int i;
   int pa = -1, pb = -1;
   for(i = 0; i < numPrec; i++)
   {
      if(isPrecedence(opA, i)) pa = i;
      if(isPrecedence(opB, i)) pb = i;
   }
   return pa <= pb || (opA == or && opB == and); // Bracket mixed OR and AND even if AND has higher precedence...
}

static bool isPrecedence(CQL2TokenType this, int l)
{
   if(this)
   {
      int o;
      for(o = 0; o < sizeof(opPrec[0]) / sizeof(opPrec[0][0]); o++)
      {
         CQL2TokenType op = opPrec[l][o];
         if(this == op)
            return true;
         else if(!op)
            break;
      }
   }
   return false;
}

public class CQL2Identifier : CQL2Node
{
public:
   String string;

   bool isValid(bool allowColon)
   {
      if(string && string[0])
      {
         int i, nb;
         unichar ch;

         // NOTE: While we treat false, true, and null as identifiers, we can't support them even double-quoted.
         if(cql2StringTokens[string]) return false; // Avoid conflict with tokens
         for(i = 0; (ch = UTF8GetChar(string + i, &nb)); i += nb)
         {
            if(!(i ? isValidCQL2IdChar(ch, allowColon) : isValidCQL2IdStart(ch, allowColon) ))
               return false;
         }
         return true;
      }
      return false;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      // NOTE: according to the spec, can be quoteless also
      bool needsQuotes = string && !isValid(o.strictCQL2);
      if(needsQuotes) out.Print('"');
      out.Print(string ? string : "<null>");
      if(needsQuotes) out.Print('"');
   }

   CQL2Identifier ::parse(CQL2Lexer lexer)
   {
      lexer.readToken();
      return { string = CopyString(lexer.token.text) };
   }

   CQL2Identifier copy()
   {
      CQL2Identifier id { string = CopyString(string) };
      return id;
   }

   ~CQL2Identifier()
   {
      delete string;
   }
};

// Expressions

public class CQL2Expression : CQL2Node
{
public:
   DataValue val;
   Class destType;
   Class expType;

   //virtual float compute();
   public virtual ExpFlags compute(FieldValue value, CQL2Evaluator evaluator, ComputeType computeType, Class instClass);

   CQL2Expression ::parse(CQL2Lexer lexer)
   {
      CQL2Expression e;

      if(lexer.strictCQL2)
         e = CQL2ExpOperation::parse(numPrec-1, lexer);
      else
         e =  CQL2ExpConditional::parse(lexer);
      if(lexer.type == lexingError ||
         lexer.type == syntaxError ||
         (lexer.nextToken && (lexer.nextToken.type == lexingError || lexer.nextToken.type == syntaxError)))
         delete e;
      return e;
   }

   public virtual void toCQL2JSON(FieldValue json) { json = { type = { nil } }; };
}

public class CQL2ExpList : CQL2List<CQL2Expression>
{
public:
   CQL2ExpList ::parse(CQL2Lexer lexer)
   {
      return (CQL2ExpList)CQL2List::parse(class(CQL2ExpList), lexer, CQL2Expression::parse, ',');
   }

   CQL2ExpList copy()
   {
      if(this)
      {
         CQL2ExpList e { };
         for(n : list)
            e.list.Add(n.copy());
         return e;
      }
      return null;
   }
}

public class CQL2Tuple : CQL2List<CQL2Expression>
{
public:

   CQL2Tuple copy()
   {
      return (CQL2Tuple)CQL2List::copy();
   }
   void print(File out, int indent, CQL2OutputOptions o)
   {
      Iterator<CQL2Expression> it { list };
      while(it.Next())
      {
         it.data.print(out, indent, o);
         if(list.GetNext(it.pointer))
            out.Print(" ");
      }
   }
}

// REVIEW: How to extensibly manage valid class names?
static bool isInstanceClass(const String s)
{
   return
      !strcmpi(s, "Text") ||
      !strcmpi(s, "Image") ||
      !strcmpi(s, "Dot")
      ;
}

static CQL2Expression parseSimplePrimaryExpression(CQL2Lexer lexer)
{
   if(lexer.peekToken().type == constant)
      return CQL2ExpConstant::parse(lexer);
   else if(lexer.nextToken.type == identifier)
   {
      CQL2ExpIdentifier exp = CQL2ExpIdentifier::parse(lexer);
      CQL2Token token = lexer.peekToken();
      bool isInstance = false;

      if(!lexer.strictCQL2)
      {
         if(token.type == '{')
            isInstance = true;
         else if(token.type == '(' && exp.identifier && exp.identifier.string)
            isInstance = isInstanceClass(exp.identifier.string);
         if(isInstance)
         {
            CQL2SpecName spec { name = CopyString(exp.identifier.string) };
            delete exp;
            return CQL2ExpInstance::parse(spec, lexer);
         }
      }
      return exp;
   }
   else if(lexer.nextToken.type == stringLiteral)
      return CQL2ExpString::parse(lexer);
   else if(!lexer.strictCQL2 && lexer.nextToken.type == '{')
      return CQL2ExpInstance::parse(null, lexer);
   else if(!lexer.strictCQL2 && lexer.nextToken.type == '[')
      return CQL2ExpArray::parse(lexer);
   else
   {
      // This could happen e.g., at the end of a list with next token being ']'
      return null;
   }
}

static CQL2Expression parsePrimaryExpression(CQL2Lexer lexer)
{
   if(lexer.peekToken().type == '(')
   {
      CQL2ExpList list;
      bool isIn = lexer.token.type == in;

      lexer.readToken();

      list = CQL2ExpList::parse(lexer);
      if(lexer.peekToken().type == ')')
         lexer.readToken();

      if(isIn || (list && (!list.list || !list.list.count || list.list.count > 1)))
         return CQL2ExpArray { elements = list };
      else
         return CQL2ExpBrackets { list = list };
   }
   else
      return parseSimplePrimaryExpression(lexer);
}

static CQL2Expression parsePostfixExpression(CQL2Lexer lexer)
{
   CQL2Expression exp = parsePrimaryExpression(lexer);
   while(exp) //true)
   {
      if(lexer.peekToken().type == '(')
         exp = CQL2ExpCall::parse(exp, lexer);
      else if(!lexer.strictCQL2 && lexer.peekToken().type == '[')
         exp = CQL2ExpIndex::parse(exp, lexer);
      else if(!lexer.strictCQL2 && lexer.nextToken.type == '.')
         exp = CQL2ExpMember::parse(exp, lexer);
      else
         break;
   }
   return exp;
}

static CQL2Expression parseTupleOrUnaryExpression(CQL2Lexer lexer)
{
   CQL2Expression exp = null;
   CQL2Tuple tuple = null;
   while((exp = parseUnaryExpression(lexer)))
   {
      CQL2TokenType type = lexer.peekToken().type;
      if(type == CQL2Token::constant || type == CQL2Token::identifier || type == CQL2Token::stringLiteral || (lexer.wktContext > 0 && type.isUnaryOperator))
      {
         if(!tuple)
            tuple = { };
         tuple.Add(exp);
      }
      else if(tuple)
         tuple.Add(exp);
      else
         break;
   }

   if(tuple)
   {
      exp = tupleToPointExpInstance(tuple);
      delete tuple;
   }
   return exp; //tuple ? (CQL2Expression)tuple : exp;
}

static CQL2Expression parseUnaryExpression(CQL2Lexer lexer)
{
   lexer.peekToken();
   if(lexer.nextToken.type.isUnaryOperator)
   {
      CQL2TokenType tokenType;
      CQL2Expression exp2;

      lexer.readToken();
      tokenType = lexer.token.type;
      exp2 = parseUnaryExpression(lexer);
      if(tokenType == minus && exp2 && exp2._class == class(CQL2ExpConstant))
      {
         CQL2ExpConstant c = (CQL2ExpConstant)exp2;
         if(c.constant.type.type == integer)
            c.constant.i *= -1;
         else
            c.constant.r *= -1;
         return c;
      }
      else
         return CQL2ExpOperation { op = tokenType, exp2 = exp2 };
   }
   else
      return parsePostfixExpression(lexer);
}

public class CQL2ExpConstant : CQL2Expression
{
public:
   FieldValue constant;
   CQL2Identifier unit;

   void print(File out, int indent, CQL2OutputOptions o)
   {
      Class type = destType ? destType : expType;  // NOTE: Color expType get converted to integer during compute()...
      if(constant.type.format == hex && (type == class(int64) || type == class(int)))
         type = null;
      else if(type == class(double) || type == class(float))
         type = null;
      // TODO: Review for 32 bit and big-endian..
      else if(type && expType && (expType != class(int64) && expType != class(uint64)) && strcmp(type.dataTypeString, expType.dataTypeString))
         type = null;
      else if(type && type.type == unitClass)
         type = null;
      if(constant.type.type == integer && constant.type.format == color)
         type = class(Color);

      if(type && !constant.type.isDateTime) // Review this type check logic
      {
         const char *(* onGetString)(void *, void *, char *, void *, ObjectNotationType *) = type._vTbl[__eCVMethodID_class_OnGetString];
         char tempString[1024];
         ObjectNotationType on = econ;
         const String s = onGetString(type, &constant.i, tempString, null, &on);
         if(s && (constant.type.format != hex || on == none))  // This (&& on == none) will force hex output for colors instead of expanded r, g, b
         {
            // TODO: Really need to clarify these rules here about adding brackets...
            bool addCurlies = on != none && type.type != systemClass && type.type != enumClass;
            if(addCurlies) out.Print("{ ");
            out.Print(s);
            if(addCurlies) out.Print(" }");
         }
         else if(constant.type.format == hex || constant.type.format == color)
         {
            char number[64];
            sprintf(number,
               (__runtimePlatform == win32) ? "#%06I64X" : "#%06llX",
               constant.i);
            out.Print(number);
         }
         else
            out.Print(constant);
      }
      else if(constant.type.isDateTime)
      {
         SecSince1970 dateSec = (SecSince1970)constant.i;
         DateTime dt = dateSec;
         TemporalOptions to {year=true, month=true, day=true};
         String dateString;

         if(dt.hour || dt.minute || dt.second)
            to |= { hour = true, minute = true, second = true };
         dateString = printTime(to, dt);
         out.Print("DateTime { '", dateString, "' }");
         delete dateString;
      }
      else if(constant.type.type == integer && (constant.type.format == hex || constant.type.format == color))
      {
         out.Print("#");
         out.Printf((__runtimePlatform == win32) ? "%I64X" : "%llX", constant.i);
      }
      else
         out.Print(constant);

      if(unit)
      {
         out.Print(" ");
         unit.print(out, indent, o);
      }
   }

   CQL2ExpConstant ::parse(CQL2Lexer lexer)
   {
      CQL2ExpConstant result = null;
      CQL2Token token = lexer.readToken();
      bool hashTag = !lexer.strictCQL2 && token.text[0] == '#';
      // check token, if starts with quote or contains comma... parse to know type, integer string etc,... set i s or r
      // no text here, use CQL2ExpString

      if(hashTag || isdigit(token.text[0]))
      {
         int multiplier = 1;
         int len = strlen(token.text);

         // REVIEW: Not in CartoSym-CSS / CQL2
         if(token.text[len-1] == 'K') multiplier = 1000;
         else if(token.text[len-1] == 'M') multiplier = 1000000;

         if(!hashTag && (
            strchr(token.text, '.') ||
            ((token.text[0] != '0' || token.text[1] != 'x') && (strchr(token.text, 'E') || strchr(token.text, 'e')))))
         {
            result = { constant = { r = strtod(token.text, null) * multiplier, type.type = real } };
            if(strchr(token.text, 'E') || strchr(token.text, 'e'))
               result.constant.type.format = exponential;
         }
         else
         {
            result = { constant = {
               i = strtoll(token.text + (int)hashTag, null, hashTag ? 16 : 0) * multiplier,
               type.type = integer
            } };
            if(hashTag || strstr(token.text, "0x"))
               result.constant.type.format = hex;
            else if(strstr(token.text, "b"))
               result.constant.type.format = binary;
            else if(token.text[0] == '0' && isdigit(token.text[1]))
               result.constant.type.format = octal;
         }

         if(!lexer.strictCQL2 && (token = lexer.peekToken()).type == identifier)
         {
            const String id = token.text;
            if(!strcmpi(id, "px") ||
               !strcmpi(id, "m") ||
               !strcmpi(id, "ft") ||
               !strcmpi(id, "pc") ||
               !strcmpi(id, "pt") ||
               !strcmpi(id, "em") ||
               !strcmpi(id, "in") ||
               !strcmpi(id, "cm") ||
               !strcmpi(id, "mm"))
               result.unit = CQL2Identifier::parse(lexer);
         }
      }
      return result;
   }

   CQL2ExpConstant copy()
   {
      CQL2ExpConstant e { constant = constant, expType = expType, destType = destType };
      if(e.constant.type.type == text && e.constant.type.mustFree)
         e.constant.s = CopyString(e.constant.s);
      return e;
   }

   ExpFlags compute(FieldValue value, CQL2Evaluator evaluator, ComputeType computeType, Class instClass)
   {
      value = constant;
      switch(value.type.type)
      {
         case real: expType = class(double); break;
         case integer: expType = class(int64); break;
      }
      return ExpFlags { resolved = true };
   }

   void toCQL2JSON(FieldValue json)
   {
      // FIXME: json.OnCopy(constant);
      json = constant;

      // TODO: Units
   }

   ~CQL2ExpConstant()
   {
      if(constant.type.mustFree == true && constant.type.type == text )
         delete constant.s;
      delete unit;
   }
}

public class CQL2ExpString : CQL2Expression
{
public:
   String string;

   void print(File out, int indent, CQL2OutputOptions o)
   {
      /*
      int len = strlen(string) * 2 + 1;
      String buf = new char[len];
      EscapeCString(buf, len, string, { escapeSingleQuote = true });
      */

      String buf = copyEscapeCQL2(string);
      out.Print('\'', buf, '\'');
      delete buf;
   }

   CQL2ExpString ::parse(CQL2Lexer lexer)
   {
      int len;
      String s;
      lexer.readToken();
      len = strlen(lexer.token.text)-2;  // len source string length for UnescapeCString()
      s = new char[len+1];
      // len = UnescapeCString(s, lexer.token.text+1, len);
      len = UnescapeCQL2String(s, lexer.token.text+1, len);
      s = renew s char[len+1];
      // memcpy(s, lexer.token.text+1, len);
      // s[len] = 0;
      return { string = s };
   }

   ExpFlags compute(FieldValue value, CQL2Evaluator evaluator, ComputeType computeType, Class instClass)
   {
      value.s = string;
      value.type = { type = text };
      expType = class(String);
      return ExpFlags { resolved = true };
   }

   CQL2ExpString copy()
   {
      CQL2ExpString e { string = CopyString(string), expType = expType, destType = destType };
      return e;
   }

   void toCQL2JSON(FieldValue json)
   {
      json = FieldValue { type = { text, mustFree = true }, s = string };
   }

   ~CQL2ExpString()
   {
      delete string;
   }
}

public class CQL2ExpIdentifier : CQL2Expression
{
public:
   CQL2Identifier identifier;
   int fieldID;

   CQL2ExpIdentifier copy()
   {
      CQL2ExpIdentifier e
      {
         identifier = identifier.copy(),
         fieldID = fieldID, // TOCHECK: Should we copy fieldID here ?
         expType = expType, destType = destType
      };
      return e;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      identifier.print(out, indent, o);
   }

   CQL2ExpIdentifier ::parse(CQL2Lexer lexer)
   {
      return { identifier = CQL2Identifier::parse(lexer) };
   }

   ExpFlags compute(FieldValue value, CQL2Evaluator evaluator, ComputeType computeType, Class instClass)
   {
      //Class c = destType ? destType : class(FieldValue); //filler
      //bool *(* onGetDataFromString)(Class, void *, const char *) = destType._vTbl[__eCVMethodID_class_OnGetDataFromString];
      ExpFlags flags { };
      //bool (* onGetDataFromString)(void *, void *, const char *) = (void *)destType._vTbl[__eCVMethodID_class_OnGetDataFromString];
      if(computeType == preprocessing && identifier.string)
      {
         if(!strcmpi(identifier.string, "null"))
         {
            value.type.type = nil;
            flags.resolved = true; // Should resolved be set for null?
         }
         else if(!strcmpi(identifier.string, "true"))
         {
            value = { { type = integer, format = boolean }, i = 1 };
            flags.resolved = true;
            expType = class(bool);
         }
         else if(!strcmpi(identifier.string, "false"))
         {
            value = { { type = integer, format = boolean }, i = 0 };
            flags.resolved = true;
            expType = class(bool);
         }
         else if(destType && (destType.type == enumClass || destType == class(Color)))
         {
            //awaiting special code here
            //enum will be an int if not color
            bool (* onGetDataFromString)(void *, void *, const char *) = (void *)destType._vTbl[__eCVMethodID_class_OnGetDataFromString];

            if(destType == class(Color))
            {
               Color color = 0;
               DefinedColor c = 0;
               if(c.class::OnGetDataFromString(identifier.string))
                  color = c;
               value.i = color;

               //if(destType != class(Color)) value.i = strtol(identifier.string, null, 0);
               expType = destType;
               value.type.type = integer;
               value.type.format = FieldValueFormat::color;
               flags.resolved = true;
            }
            else
            {
               flags.resolved = onGetDataFromString(destType, &value.i, identifier.string);
               value.type.type = flags.resolved ? integer : nil;
            }
         }
         else if(evaluator != null)
         {
            bool isFunction = destType == class(GlobalFunction);

            expType = evaluator.evaluatorClass.resolve(evaluator, identifier, isFunction, &fieldID, &flags);

            if(isFunction && fieldID != -1)
            {
               value.i = fieldID;
               value.type.type = integer;
            }
         }
         else
            value.type.type = nil;
      }
      else if(evaluator != null)
      {
         bool isFunction = destType == class(GlobalFunction);
         evaluator.evaluatorClass.compute(evaluator, fieldID, identifier, isFunction, value, &flags);
      }
      else
         value.type.type = nil;
      return flags;
   }

   CQL2ExpIdentifier()
   {
      fieldID = -1;
   }

   // REVIEW: How to identify enum values (we would need dest type to resolve here)? Are they allowed unquoted in CartoSym-CSS?
   static bool isEnumValue(const String s)
   {
      if(!strcmp(s, "coverage") || !strcmp(s, "vector"))
         return true;
      return false;
   }

   static bool isSysId(const String s)
   {
           if(strstr(s, "dataLayer") == s) return true;
      else if(strstr(s, "viz") == s) return true;
      return false;
   }

   void toCQL2JSON(FieldValue json)
   {
      String idString = CopyString(identifier ? identifier.string : null);

      if(idString && !strcmpi(idString, "true"))
         json = { type = { integer, format = boolean }, i = 1 };
      else if(idString && !strcmpi(idString, "false"))
         json = { type = { integer, format = boolean }, i = 0 };
      else if(isEnumValue(idString))
         json = FieldValue { type = { text, mustFree = true }, s = idString };
      else
      {
         Map<String, FieldValue> m { };
         json = { type = { map }, m = m };

         m[isSysId(idString) ? "sysId" : "property"] = FieldValue { type = { text, mustFree = true }, s = idString };
      }
   }

   ~CQL2ExpIdentifier()
   {
      delete identifier;
   }
}

public class CQL2ExpOperation : CQL2Expression
{
public:
   CQL2TokenType op;
   CQL2Expression exp1, exp2;
   bool isExp;
   bool falseNullComparisons;

   ExpFlags compute(FieldValue value, CQL2Evaluator evaluator, ComputeType computeType, Class instClass) //float
   {
      ExpFlags flags { };

      value = { type = { nil } };
      if(exp1 && exp2)
      {
         FieldValue val1 { };
         FieldValue val2 { };
         ExpFlags flags1, flags2 = 0;
         FieldTypeEx type {};
         OpTable * tbl;

         // TODO: Review this (inheritance of parent expression dest type?)
         exp1.destType = destType;

         flags1 = exp1.compute(val1, evaluator, computeType, instClass);
         if(!(flags1.resolved && op == and && val1.type.type == integer && !val1.i)) // Lazy AND evaluation
            flags2 = exp2.compute(val2, evaluator,
               computeType == runtime && !flags1.resolved && op == and ? preprocessing : computeType, instClass);
         flags = flags1 | flags2;

         if(op == in)
         {
            CQL2List<CQL2Expression> l = (CQL2List<CQL2Expression>)exp2;
            if(l && l._class == class(CQL2ExpBrackets))
            {
               l = ((CQL2ExpBrackets)l).list;
            }
            else if(l && l._class == class(CQL2ExpArray))
            {
               l = ((CQL2ExpArray)l).elements;
            }
            if(l && eClass_IsDerived(l._class, class(CQL2List<CQL2Expression>)))
            {
               FieldValue v { type = { type = nil } };
               FieldValue v1 { };

               v1.OnCopy(val1);

               for(e : l.list)
               {
                  CQL2Expression ne = e;
                  FieldValue v2 { type = { type = nil } };
                  ExpFlags f2 = ne.compute(v2, evaluator, computeType, instClass);
                  if(flags1.resolved && v1.type.type != nil)
                  {
                     if(f2.resolved)
                     {
                        if(op >= stringStartsWith && op <= stringNotContains)
                           type.type = text;
                        else
                        {
                           type.type = (val1.type.type == real || v2.type.type == real) ? real :
                                  (val1.type.type == integer || v2.type.type == integer) ? integer : text;
                           type.isDateTime = (val1.type.isDateTime || v2.type.isDateTime);
                        }

                        if(v1.type.type != type.type)
                           convertFieldValue(v1, type, v1);
                        if(v2.type.type != type.type)
                           convertFieldValue(v2, type, v2);
                        if(v2.type.type == type.type)
                        {
                           tbl = &opTables[type.type];
                           tbl->Equ(v, v1, v2);
                           if(v.i)
                           {
                              v2.OnFree();
                              break;
                           }
                        }
                     }
                  }
                  else
                     flags |= f2;
                  v2.OnFree();
               }
               v1.OnFree();
               value = v;

               flags.resolved = flags1.resolved && flags2.resolved;
            }
            else
               flags.resolved = false;
         }
         else
         {
            // REVIEW: condition for overall flags to be resolved
            if(op >= stringContains && op <= stringNotEndsW)
               type.type = text;
            else
            {
               type.type = (val1.type.type == real || val2.type.type == real) ? real :
                      (val1.type.type == integer || val2.type.type == integer) ? integer : text;
               type.isDateTime = (val1.type.isDateTime || val2.type.isDateTime);
            }

            tbl = &opTables[type.type];

            if(flags1.resolved && val1.type.type != type.type && val1.type.type != nil)
               convertFieldValue(val1, type, val1);

            if((flags1.resolved && flags2.resolved) ||
               (flags.resolved && op == '&' && (flags1.resolved ? !val1.i : !val2.i)) ||
               (flags.resolved && op == '|' && (flags1.resolved ? val1.i : val2.i)))
            {
               if(!flags1.resolved)
                  val1.OnFree(), val1 = { type = { integer }, i = 0 };
               if(!flags2.resolved)
                  val2.OnFree(), val2 = { type = { integer }, i = 0 };
               if(val2.type.type != nil && val2.type.type != type.type)
                  convertFieldValue(val2, type, val2);

               if(val1.type.type != nil && val1.type.type == val2.type.type)
               {
                  switch(op)
                  {
                     case multiply:             tbl->Mul       (value, val1, val2); break;
                     case divide:   if(val2.i)  tbl->Div       (value, val1, val2); break;
                     case minus:                tbl->Sub       (value, val1, val2); break;
                     case plus:                 tbl->Add       (value, val1, val2); break;
                     case modulo:               tbl->Mod       (value, val1, val2); break;
                     case equal:                tbl->Equ       (value, val1, val2); expType = class(bool); break;
                     case notEqual:             tbl->Nqu       (value, val1, val2); expType = class(bool); break;
                     case and:                  tbl->And       (value, val1, val2); expType = class(bool); break;
                     case or:                   tbl->Or        (value, val1, val2); expType = class(bool); break;
                     case greater:              tbl->Grt       (value, val1, val2); expType = class(bool); break;
                     case smaller:              tbl->Sma       (value, val1, val2); expType = class(bool); break;
                     case greaterEqual:         tbl->GrtEqu    (value, val1, val2); expType = class(bool); break;
                     case smallerEqual:         tbl->SmaEqu    (value, val1, val2); expType = class(bool); break;
                     case intDivide:            tbl->DivInt    (value, val1, val2); break;
                     case stringStartsWith:     tbl->StrSrt    (value, val1, val2); expType = class(bool); break;
                     case stringNotStartsW:     tbl->StrNotSrt (value, val1, val2); expType = class(bool); break;
                     case stringEndsWith:       tbl->StrEnd    (value, val1, val2); expType = class(bool); break;
                     case stringNotEndsW:       tbl->StrNotEnd (value, val1, val2); expType = class(bool); break;
                     case stringContains:       tbl->StrCnt    (value, val1, val2); expType = class(bool); break;
                     case stringNotContains:    tbl->StrNotCnt (value, val1, val2); expType = class(bool); break;
                     case bitAnd:               tbl->BitAnd    (value, val1, val2); break;
                     case bitOr:                tbl->BitOr     (value, val1, val2); break;
                     case bitXor:               tbl->BitXor    (value, val1, val2); break;
                     case lShift:               tbl->LShift    (value, val1, val2); break;
                     case rShift:               tbl->RShift    (value, val1, val2); break;
                  }
                  flags.resolved = value.type.type != nil;

                  // REVIEW: Assigning expType? -- Improve on promotions/conversion rules?
                  if(!expType)
                  {
                     expType = exp1.expType && exp1.expType == class(Meters) ? exp1.expType :
                               exp2.expType && exp2.expType == class(Meters) ? exp2.expType :
                               exp1.expType && exp1.expType == class(double) ? exp1.expType :
                               exp2.expType && exp2.expType == class(double) ? exp2.expType :
                               exp1.expType ? exp1.expType : exp2.expType;
                  }
               }
               else if((val1.type.type == nil || val2.type.type == nil) && (op == equal || op == notEqual))
               {
                  // Null equality checks
                  bool result;

                  if(falseNullComparisons)
                  {
                     // REVIEW: Should the be false or null?
                     result = false;
                  }
                  else if(op == equal)
                     result = val1.type.type == val2.type.type;
                  else
                     result = val1.type.type != val2.type.type;
                  expType = class(bool);
                  flags.resolved = true;
                  value = { type = { integer }, i = result };
               }
               else
                  flags.resolved = false;
            }
            else if(flags1 == 64) // FIXME: dimensions work-around
            {
               // For now we only extract dimensions, and don't have a setup / evaluator for them
               value = { type = { integer }, i = 1 };
               flags.resolved = true;
            }
            else
               flags.resolved = false;
         }

         if(computeType == preprocessing)
         {
            if(flags1.resolved && !flags2.resolved)
               exp1 = simplifyResolved(val1, exp1);
            else if(!flags1.resolved && flags2.resolved)
               exp2 = simplifyResolved(val2, exp2);
         }

         val1.OnFree();
         val2.OnFree();
      }
      else if(exp2)
      {
         FieldValue val2 { };
         ExpFlags flags2 = exp2.compute(val2, evaluator, computeType, instClass);
         OpTable * tbl = &opTables[val2.type.type];
         flags = flags2;
         if(flags2.resolved)
         {
            if(val2.type.type != nil)
            {
               switch(op)
               {
                  case '-':    tbl->Neg(value, val2);    break;
                  case '!':    tbl->Not(value, val2);    expType = class(bool); break;
                  case bitNot: tbl->BitNot(value, val2); break;
               }
            }
            else if(op == not)
            {
               flags.resolved = true;
               value = { type = { integer }, i = !falseNullComparisons };
               expType = class(bool);
            }
            else
               flags.resolved = false;
         }
         val2.OnFree();
      }
      return flags;
   }

   CQL2ExpOperation copy()
   {
      CQL2ExpOperation e
      {
         op = op,
         exp1 = exp1 ? exp1.copy() : null,
         exp2 = exp2 ? exp2.copy() : null,
         expType = expType, destType = destType,
         falseNullComparisons = falseNullComparisons
      };
      return e;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      CQL2ExpIdentifier exp2Id = exp2 && exp2._class == class(CQL2ExpIdentifier) ? (CQL2ExpIdentifier)exp2 : null;
      if(exp1)
      {
         if(exp1._class == (void *)(uintptr)0xecececececececec)
            out.Print("<freed exp>");
         else
            exp1.print(out, indent, o);
         if(exp2) out.Print(" ");
      }
      if((op == equal || op == notEqual) && exp2Id && exp2Id.identifier && exp2Id.identifier.string &&
         !strcmpi(exp2Id.identifier.string, "null"))
         out.Print(op == equal ? "IS" : "IS NOT");
      else
         op.print(out, indent, o);
      if(exp2)
      {
         if(exp1 || op == bitNot ||
            (op == not && (exp2._class != class(CQL2ExpOperation) && exp2._class != class(CQL2ExpBrackets))))
            out.Print(" ");
         if(op == not && exp2._class == class(CQL2ExpOperation))
         {
            out.Print("(");
            Print("WARNING: This should be in parentheses");
         }

         if(exp2._class == (void *)(uintptr)0xecececececececec)
            out.Print("<freed exp>");
         else
            exp2.print(out, indent, o);

         if(op == not && exp2._class == class(CQL2ExpOperation))
            out.Print(")");
      }
   }

   CQL2Expression ::parse(int prec, CQL2Lexer lexer)
   {
      CQL2Expression exp = (prec > 0) ? parse(prec-1, lexer) : parseTupleOrUnaryExpression(lexer);
      while(isPrecedence(lexer.peekToken().type, prec))
      {
         CQL2TokenType op = lexer.readToken().type;
         if(exp || op.isUnaryOperator)
         {
            if(op == not)
            {
               op = lexer.peekToken().type;
               if(op == between || op == like || op == in)
               {
                  CQL2ExpOperation expOp { exp1 = exp, op = op == between ? notBetween : op == like ? notLike : notIn };
                  lexer.readToken();
                  expOp.exp2 = (prec > 0) ? parse(prec-1, lexer) : parseUnaryExpression(lexer);
                  exp = expOp;
               }
               else
                  // Syntax error
                  delete exp;
            }
            else
            {
               CQL2ExpOperation expOp { exp1 = exp, op = op };
               if(op == is)
               {
                  if(lexer.peekToken().type == not)
                  {
                     expOp.op = notEqual;
                     lexer.readToken();
                  }
                  else
                     expOp.op = equal;
                  expOp.isExp = true;
               }
               expOp.exp2 = (prec > 0) ? parse(prec-1, lexer) : parseUnaryExpression(lexer);
               exp = expOp;
               if(!expOp.exp2)
                  delete exp; // Syntax error: missing 2nd operand
            }
         }
         else
            // Syntax error: binary operator with only right operand
            delete exp;
      }
      return exp;
   }

   ~CQL2ExpOperation()
   {
      delete exp1;
      delete exp2;
   }

   void toCQL2JSON(FieldValue json)
   {
      CQL2TokenType op = this.op;
      CQL2ExpIdentifier exp2Id = exp2 && exp2._class == class(CQL2ExpIdentifier) ?
         (CQL2ExpIdentifier) exp2 : null;
      bool exp2IsNull = exp2Id && exp2Id.identifier && exp2Id.identifier.string &&
               !strcmpi(exp2Id.identifier.string, "null");
      Map<String, FieldValue> m { };
      Array<FieldValue> args { };
      const String opString = null;

      json = { type = { map }, m = m };

      if((op == notEqual && exp2IsNull) || op == notLike || op == notBetween)
      {
         // There are no direct NOT operators for these
         m["op"] = FieldValue { type = { text }, s = (void *)(String)"not" };
         m["args" ] = FieldValue { type = { array }, a = args };

         op = (op == notEqual) ? equal : (op == notLike) ? like : between;
         m = { };
         args.Add({ type = { map }, m = m });
         args = { };
      }

      switch(op)
      {
         case equal: opString = exp2IsNull ? "isNull" : "="; break;
         case smaller:  opString = "<"; break;
         case greater:  opString = ">"; break;
         case plus:     opString = "+"; break;
         case minus:    opString = "-"; break;
         case multiply: opString = "*"; break;
         case divide:   opString = "/"; break;
         // TOOD: Handle between conversion here
         case smallerEqual: opString = "<="; break;
         case greaterEqual: opString = ">="; break;
         case is:           opString = "is"; break;
         case notEqual:     opString = "<>"; break;
         case not:          opString = "not"; break;
         case and:          opString = "and"; break;
         case or:           opString = "or"; break;
         case in:           opString = "in"; break;
         case intDivide:    opString = "div"; break;
         case like:         opString = "like"; break;
         case between:      opString = "between"; break;
         case power:        opString = "^"; break;
      }
      m["op"] = FieldValue { type = { text }, s = (void *)(String)opString };
      m["args" ] = FieldValue { type = { array }, a = args };

      if(exp1)
      {
         FieldValue a { };
         exp1.toCQL2JSON(a);
         args.Add(a);
      }
      if(exp2 && !exp2IsNull)
      {
         FieldValue a { };
         exp2.toCQL2JSON(a);
         args.Add(a);
      }
   }
}

public class CQL2ExpBrackets : CQL2Expression
{
public:
   CQL2ExpList list;

   ExpFlags compute(FieldValue value, CQL2Evaluator evaluator, ComputeType computeType, Class instClass)
   {
      ExpFlags flags = 0;
      if(list)
      {
         Iterator<CQL2Expression> last { container = list, pointer = list.GetLast() };
         CQL2Expression lastExp = last.data;
         if(lastExp)
         {
            lastExp.destType = destType;
            flags = lastExp.compute(value, evaluator, computeType, instClass);
            expType = lastExp.expType;
         }
      }
      return flags;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      out.Print("(");
      if(list) list.print(out, indent, o);
      out.Print(")");
   }

   CQL2ExpBrackets copy()
   {
      return CQL2ExpBrackets { list = list.copy(), expType = expType, destType = destType };
   }

   void toCQL2JSON(FieldValue json)
   {
      json = { type = { nil } };
      if(list)
      {
         Iterator<CQL2Expression> last { container = list, pointer = list.GetLast() };
         CQL2Expression lastExp = last.data;
         if(lastExp)
            lastExp.toCQL2JSON(json);
      }
   }

   ~CQL2ExpBrackets()
   {
      delete list;
   }
}

public class CQL2ExpConditional : CQL2Expression
{
public:
   CQL2Expression condition;
   CQL2ExpList expList;
   CQL2Expression elseExp;
   bool result; // Work-around for simplifyResolved() challenges not having access to computed condition FieldValue

   CQL2ExpConditional copy()
   {
      CQL2ExpConditional e
      {
         condition = condition ? condition.copy() : null,
         expList = expList ? expList.copy() : null,
         elseExp = elseExp ? elseExp.copy() : null,
         expType = expType, destType = destType
      };
      return e;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      if(condition) condition.print(out, indent, o);
      out.Print(" ? ");
      if(expList) expList.print(out, indent, o);
      out.Print(" : ");
      if(elseExp)
         elseExp.print(out, indent, o);
   }

   CQL2Expression ::parse(CQL2Lexer lexer)
   {
      CQL2Expression exp = CQL2ExpOperation::parse(numPrec-1, lexer);
      if(lexer.peekToken().type == '?')
      {
         lexer.readToken();
         exp = CQL2ExpConditional { condition = exp, expList = CQL2ExpList::parse(lexer) };
         if(lexer.peekToken().type == ':')
         {
            lexer.readToken();
            ((CQL2ExpConditional)exp).elseExp = CQL2ExpConditional::parse(lexer);
            if(!((CQL2ExpConditional)exp).elseExp)
               delete exp;
         }
         else
         {
#ifdef _DEBUG
            PrintLn("CQL2-Text/CartoSym-CSS Syntax Error: Conditional expression missing else condition ",
               " at line ", lexer.pos.line, ", column ", lexer.pos.col);
#endif
            delete exp; // Syntax error
         }
      }
      return exp;
   }

   ExpFlags compute(FieldValue value, CQL2Evaluator evaluator, ComputeType computeType, Class instClass)
   {
      // RVVIEW: computeType ignored here ?
      ExpFlags flags = 0;
      FieldValue condValue { };
      ExpFlags flagsCond = condition.compute(condValue, evaluator, computeType, instClass);
      if(flagsCond.resolved)
      {
         result = (bool)condValue.i;
         if(condValue.i)
         {
            CQL2Expression last = expList.lastIterator.data;   // CS Only currently supports a single expression...
            if(last)
            {
               last.destType = destType;
               flags = last.compute(value, evaluator, computeType, instClass);
               if(!expType) expType = last.expType;
            }
         }
         else
         {
            flags = elseExp.compute(value, evaluator, computeType, instClass);
            if(elseExp && !expType) expType = elseExp.expType;
         }
         if(!flags.resolved && computeType == preprocessing)   // REVIEW: Do we avoid simplifyResolved() at runtime so as to not modify expressions?
            condition = simplifyResolved(condValue, condition);
          // TODO: Support for replacing condition expression entirely eventually?
      }
      else
      {
         CQL2Expression last = expList.lastIterator.data;   // CS Only currently supports a single expression...
         FieldValue val1 { };
         FieldValue val2 { };
         ExpFlags flags1;
         ExpFlags flags2;
         if(last) last.destType = destType;
         if(elseExp) elseExp.destType = destType;
         flags1 = last ? last.compute(val1, evaluator, computeType, instClass) : 0;
         flags2 = elseExp ? elseExp.compute(val2, evaluator, computeType, instClass) : 0;

         flags = (flagsCond | flags1 | flags2) & ~ ExpFlags { resolved = true };
         if(flags1.resolved)
         {
            expList.TakeOut(last);
            expList.Free();
            expList.Add(simplifyResolved(val1, last));
         }
         if(flags2.resolved)
            elseExp = simplifyResolved(val2, elseExp);
      }
      return flags;
   }

   ~CQL2ExpConditional()
   {
      delete condition;
      delete expList;
      delete elseExp;
   }
}

public class CQL2ExpIndex : CQL2Expression
{
public:
   CQL2Expression exp;
   CQL2ExpList index;

   CQL2ExpIndex copy()
   {
      CQL2ExpIndex e { exp = exp.copy(), index = index.copy(), expType = expType, destType = destType };
      return e;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      if(exp) exp.print(out, indent, o);
      out.Print("[");
      if(index) index.print(out, indent, o);
      out.Print("]");
   }

   CQL2ExpIndex ::parse(CQL2Expression e, CQL2Lexer lexer)
   {
      CQL2ExpIndex exp;
      lexer.readToken();
      exp = CQL2ExpIndex { exp = e, index = CQL2ExpList::parse(lexer) };
      if(lexer.peekToken().type == ']')
         lexer.readToken();
      return exp;
   }
   ExpFlags compute(FieldValue value, CQL2Evaluator evaluator, ComputeType computeType, Class instClass)
   {
      ExpFlags flags { };
      //value = exp.compute;
      return flags;
   }

   ~CQL2ExpIndex()
   {
      delete exp;
      delete index;
   }
}

public class CQL2ExpMember : CQL2Expression
{
public:
   CQL2Expression exp;
   CQL2Identifier member;

   void print(File out, int indent, CQL2OutputOptions o)
   {
      if(exp) exp.print(out, indent, o);
      out.Print(".");
      if(member)
         member.print(out, indent, o);
   }

   CQL2ExpMember copy()
   {
      CQL2ExpMember e { exp = exp.copy(), member = member.copy(), expType = expType, destType = destType };
      return e;
   }

   CQL2ExpMember ::parse(CQL2Expression e, CQL2Lexer lexer)
   {
      lexer.readToken();
      return { exp = e, member = CQL2Identifier::parse(lexer) };
   }
   ExpFlags compute(FieldValue value, CQL2Evaluator evaluator, ComputeType computeType, Class instClass)
   {
      ExpFlags flags { };
      FieldValue val { };
      ExpFlags expFlg = exp.compute(val, evaluator, computeType, instClass);
      // REVIEW: Can we check for runtime here?
      // REVIEW: If the expression is really resolved during preprocessing, it might be possible to compute it already,
      //         but some scenarios might not yet be handled properly
      if(expFlg.resolved && evaluator != null && (!expType || computeType == runtime) && exp.expType)
      {
         // FIXME: Can we compute this prop and save it in class to compute it only during preprocessing?
         DataMember prop = eClass_FindDataMember(exp.expType, member.string, exp.expType.module, null, null);
         if(!prop)
         {
            prop = (DataMember)eClass_FindProperty(exp.expType, member.string, exp.expType.module);
         }
         // This is not right, the type of the member is different...: expType = exp.expType;
         if(prop)
         {
            if(!prop.dataTypeClass)
               prop.dataTypeClass = eSystem_FindClass(__thisModule.application, prop.dataTypeString);
            expType = prop.dataTypeClass;

            evaluator.evaluatorClass.evaluateMember(evaluator, prop, exp, val, value, &flags);

            if(computeType != runtime)
               expFlg.resolved = false;
            flags = expFlg;
         }
         else
         {
            flags.invalid = true;
            value = { { nil } };
         }
      }
      else
      {
         expFlg.resolved = false; // Avoid resolved = true which will result in simplyResolved()
         flags = expFlg;
         value = { { nil } };
      }
      val.OnFree();
      return flags;
   }

   ~CQL2ExpMember()
   {
      delete exp;
      delete member;
   }
}

public class CQL2ExpCall : CQL2Expression
{
public:
   CQL2Expression exp;
   CQL2ExpList arguments;

   ExpFlags compute(FieldValue value, CQL2Evaluator evaluator, ComputeType computeType, Class instClass)
   {
      ExpFlags flags { };

      value.type.type = nil;
      if(exp)
      {
         FieldValue expValue { type = { nil } };
         FieldValue args[50]; // Max 50 args for now?
         int i, numArgs = 0;
         subclass(CQL2Evaluator) evaluatorClass = evaluator.evaluatorClass;

         if(computeType == preprocessing)
            exp.destType = class(GlobalFunction);

         flags |= exp.compute(expValue, evaluator, computeType, instClass);
         if(arguments)
         {
            bool nonResolved = false;
            Link<CQL2Expression> a;

            flags.resolved = false;
            if(computeType == preprocessing)
               expType = evaluatorClass.resolveFunction(evaluator, expValue, arguments, &flags, destType);
                                                                     // WARNING: This may not be enough for interpolate() / map()
            for(a = (Link<CQL2Expression>)arguments.list.first; a && numArgs < 50; a = a.next)
            {
               CQL2Expression arg = (CQL2Expression)(uintptr)*&a.data;
               FieldValue * argV = &args[numArgs++];
               flags.resolved = false;

               *argV = { }; // FIXME: compute() sometimes returns uninitialized value
               flags |= arg.compute(argV, evaluator, computeType, instClass);

               // NOTE: for interpolation handling use color format, CQL2Evaluator_computeFunction does not have access to destType
               if(destType == class(Color) && argV->type == { integer, format = hex })
                  argV->type = { integer, format = color };
               if(!flags.resolved)
                  nonResolved = true;
            }
            if(nonResolved) flags.resolved = false;
         }
         // REVIEW: If the expression is really resolved during preprocessing, it might be possible to compute it already,
         //         but some scenarios might not yet be handled properly
         // We need to evaluate the function if resolved is true (should not yet be set if e.g., featureID / geometry is needed)
         if(evaluator != null && flags.resolved && (computeType == runtime || !flags.isNotLiteral))
            expType = evaluatorClass.computeFunction(evaluator, value, expValue, args, numArgs, arguments, &flags);
         for(i = 0; i < numArgs; i++)
            args[i].OnFree();
         expValue.OnFree();
      }
      return flags;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      if(exp) exp.print(out, indent, o);
      out.Print("(");
      if(arguments) arguments.print(out, indent, o);
      out.Print(")");
   }

   CQL2ExpCall copy()
   {
      CQL2ExpCall e { exp = exp.copy(), arguments = arguments.copy(), expType = expType, destType = destType };
      return e;
   }

   CQL2ExpCall ::parse(CQL2Expression e, CQL2Lexer lexer)
   {
      /* NOTE: for WKT types, increment a wktContext counter variable, and decrement once we get out
      then the unaryOperator check in parseTupleOrPostfix would only be considered if that is > 0*/
      CQL2ExpCall exp;
      bool isWKT = false;
      String str = e.toString(0);
      lexer.readToken();

      if(!strcmpi(str, "polygon") || !strcmpi(str, "point") || !strcmpi(str, "bbox") ||
         !strcmpi(str, "lineString") || !strcmpi(str, "multipolygon") || !strcmpi(str, "multipoint") ||
         !strcmpi(str, "multilinestring"))
      {
         isWKT = true;
         lexer.wktContext++;
      }
      exp = CQL2ExpCall { exp = e, arguments = CQL2ExpList::parse(lexer) };
      if(lexer.peekToken().type == ')')
         lexer.readToken();
      if(isWKT)
         lexer.wktContext--;
      delete str;
      return exp;
   }

   static bool ::readGeometryFromCQL2(Geometry geometry, CQL2Expression cql2)
   {
      bool result = false;

      if(cql2)
      {
         CQL2Expression iCQL2 = convertToInternalCQL2(cql2);
         if(iCQL2)
         {
            FieldValue val { };
            CQL2Evaluator evaluator { class(CQL2Evaluator) };

            iCQL2.compute(val, evaluator, preprocessing, null);
            iCQL2.compute(val, evaluator, runtime, null);

            if(val.type.type == blob && val.b)
            {
               /*const */Geometry * g = val.b;

               if(g->type != none)
               {
                  bool owned = g->subElementsOwned;
                  g->subElementsOwned = true;
                  geometry.OnCopy(g);
                  g->subElementsOwned = owned;

                  result = true;
               }
            }
            delete iCQL2;
         }
      }
      return result;
   }

   void toCQL2JSON(FieldValue json)
   {
      CQL2ExpIdentifier expId = exp && exp._class == class(CQL2ExpIdentifier) ?
         (CQL2ExpIdentifier) exp : null;
      const String expIdString = expId && expId.identifier ? expId.identifier.string : null;
      if(expIdString && (
         !strcmpi(expIdString, "POLYGON") ||
         !strcmpi(expIdString, "MULTIPOLYGON") ||
         !strcmpi(expIdString, "LINESTRING") ||
         !strcmpi(expIdString, "MULTILINGSTRING") ||
         !strcmpi(expIdString, "POINT") ||
         !strcmpi(expIdString, "MULTIPOINT") ||
         !strcmpi(expIdString, "GEOMETRYCOLLECTION") ||
         !strcmpi(expIdString, "BBOX")))
      {
         Geometry geometry { };
         TempFile f { };
         JSONParser parser { f = f };
         FieldValue fv;

         readGeometryFromCQL2(geometry, this);

         writeGeoJSONGeometry(f, geometry, 0, 0);
         f.Seek(0, start);

         if(parser.GetObject(class(FieldValue), (void **)&fv) != success)
            fv = { type = { nil } };

         json = fv;

         geometry.OnFree();
         delete f;
         delete parser;
      }
      else
      {
         String idString = CopyString(expIdString);
         Map<String, FieldValue> m { };
         Array<FieldValue> args { };

         json = { type = { map }, m = m };

         if(idString)
         {
            // Automatically converting to lower case for CQL2-JSON
            // It is not clear whether CQL2-Text allows both lowercase and uppercase
            if(!strcmpi(idString, "casei") ||
               !strcmpi(idString, "accenti") ||
               SearchString(idString, 0, "s_", false, false) == idString ||
               SearchString(idString, 0, "t_", false, false) == idString ||
               SearchString(idString, 0, "a_", false, false) == idString)
               strlwr(idString);
         }

         // TODO: Handle pow() conversion

         m["op"] = FieldValue { type = { text, mustFree = true }, s = idString };
         m["args" ] = FieldValue { type = { array }, a = args };

         if(arguments)
         {
            for(arg : arguments)
            {
               CQL2Expression argument = arg;
               FieldValue a { };

               argument.toCQL2JSON(a);
               args.Add(a);
            }
         }
      }
   }

   ~CQL2ExpCall()
   {
      delete exp;
      delete arguments;
   }
}

public class CQL2ExpArray : CQL2Expression
{
public:
   CQL2ExpList elements;
   Array array;

   CQL2ExpArray copy()
   {
      CQL2ExpArray e { elements = elements.copy(), expType = expType, destType = destType };
      return e;
   }

   CQL2ExpArray ::parse(CQL2Lexer lexer)
   {
      // Currently handled by parsePrimaryExpression() instead
      CQL2ExpArray exp { };
      lexer.readToken();
      exp.elements = CQL2ExpList::parse(lexer);
      // REVIEW:
      // exp.elements = (CQL2List<CQL2Expression>)CQL2List::parse(class(CQL2List<CQL2Expression>), lexer, CQL2Expression::parse, ',');
      if(lexer.peekToken().type == ')' || lexer.peekToken().type == ']')
         lexer.readToken();
      return exp;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      Class type = expType ? expType : destType;
      ClassTemplateArgument * a = type ? &type.templateArgs[0] : null;
      Class et = a ? a->dataTypeClass : null;
      int count = elements ? elements.GetCount() : 0;

      if(!count || !et || (et.type != structClass && et.type != normalClass))
      {
         out.Print(o.strictCQL2 ? "(" : "[ ");
         if(elements) elements.print(out, indent, o);
         out.Print(o.strictCQL2 ? ")" : " ]");
      }
      else
      {
         int i = 0;

         out.PrintLn(o.strictCQL2 ? "(" : "[");
         indent++;
         for(e : elements)
         {
            printIndent(indent, out);
            e.print(out, indent, o);
            if(++i < count) out.Print(",");
            out.PrintLn("");
         }
         indent--;
         printIndent(indent, out);
         out.Print(o.strictCQL2 ? ")" : "]");
      }
   }

   ExpFlags compute(FieldValue value, CQL2Evaluator evaluator, ComputeType computeType, Class instClass)
   {
      ExpFlags flags { };
      bool resolved = true;
      Class type = expType ? expType : destType;
      int i = 0;

      // TOCHECK: any issue to set resolved to true if all elements are resolved?
      delete array;

      if(!type && elements)
      {
         CQL2Expression e0 = elements[0];
         if(e0)
         {
            Class c;
            if(computeType == preprocessing && !e0.expType)
            {
               FieldValue v { };
               e0.compute(v, evaluator, computeType, null);
               v.OnFree();
            }
            c = e0.expType;
            if(!c || c == class(int64))
               c = class(double);
            if(c)
            {
               char name[1024];
               sprintf(name, "Array<%s>", c.name);
               type = eSystem_FindClass(__thisModule.application, name);
            }
         }

         // Default type?
         /*
         if(elements[0].expType == class(String))
            type = class(Array<String>);
         else
            type = class(Array<double>);
         */
      }

      if(type && type == class(FieldValue))
         type = class(Array<FieldValue>);

      if(type && computeType == runtime && elements)
      {
         if(type.templateClass == class(Container))
         {
            char name[1024];
            strcpy(name, "Array");
            strcat(name, type.name + 9);
            type = eSystem_FindClass(__thisModule.application, name);
         }

         if(type == class(Array) || eClass_IsDerived(type, class(Container)) || eClass_IsDerived(type, class(Array)))
         {
            array = eInstance_New(type);
            array.size = elements.GetCount();
            array._refCount = 1;
            flags.resolved = true;
         }
      }

      for(e : elements)
      {
         CQL2Expression exp = e;
         FieldValue v { };
         ExpFlags flg;

         if(type && eClass_IsDerived(type, class(Container)))
         {
            ClassTemplateArgument a = type.templateArgs[0];
            Class c = a.dataTypeClass;

            exp.destType = c;

            flg = exp.compute(v, evaluator, computeType, null);

            if(computeType == runtime && flg.resolved && array)
            {
               if(c == class(FieldValue))
               {
                  Iterator<FieldValue> it { (Array<FieldValue>)array };
                  if(it.Index(i, true))
                     it.SetData(v);
               }
               else if(v.type.type == real)
               {
                  if(c && (c.type == enumClass || c.type == bitClass || c.type == systemClass || c.type == unitClass))
                  {
                     Iterator<double> it { (Array<double>)array };
                     if(it.Index(i, true))
                        it.SetData(v.r);
                  }
                  else
                     flg.resolved = false;
               }
               else if(v.type.type == integer)
               {
                  if(c && (c.type == enumClass || c.type == bitClass || c.type == systemClass || c.type == unitClass))
                  {
                     Iterator<int64> it { (Array<int64>)array };
                     if(it.Index(i, true))
                        it.SetData(v.i);
                  }
                  else
                     flg.resolved = false;
               }
               else if(v.type.type == text)
               {
                  if(c && c.type == normalClass && !strcmpi(c.dataTypeString, "char *"))
                  {
                     Iterator<String> it { (Array<String>)array };
                     if(it.Index(i, true))
                        it.SetData(v.s);
                  }
                  else
                     flg.resolved = false;
               }
               else if(v.type.type == blob)
               {
                  if(c && (c.type == structClass || c.type == noHeadClass || c.type == normalClass))
                  {
                     Iterator<uintptr> it { (Array<uintptr>)array };
                     if(it.Index(i, true))
                        it.SetData((uintptr)v.b);
                  }
                  else
                     flg.resolved = false;
               }
            }

            flags |= flg;
            if(!flg.resolved)
            {
               resolved = false;
               if(array)
                  /*array.Free(), */delete array; // REVIEW:
            }

            v.OnFree();
         }
         else
            PrintLn("ERROR: null destination type!");

         i++;
      }

      if(computeType == runtime)
      {
         if(resolved)
            value = { type = { array }, a = (Array<FieldValue>)array };
         flags.resolved = resolved;
      }
      else
         // REVIEW: Shouldn't resolved sometimes be set in preprocessing, if all elements are resolved?
         // if(!resolved) flags.resolved = false;
         flags.resolved = false;
      return flags;
   }

   void toCQL2JSON(FieldValue json)
   {
      Array<FieldValue> array { };

      if(elements)
      {
         Iterator<CQL2Expression> it { container = elements };
         int i = 0;
         Class elType = null;
         if(destType && eClass_IsDerived(destType, class(Container)))
         {
            ClassTemplateArgument arg = destType.templateArgs[0];
            elType = arg.dataTypeClass;
            if(!elType && arg.dataTypeString)
               elType = arg.dataTypeClass = eSystem_FindClass(destType.module, arg.dataTypeString);
         }

         array.size = elements.GetCount();
         while(it.Next())
         {
            CQL2Expression e = it.data;

            if(elType)
               e.destType = elType;

            e.toCQL2JSON(array[i]);
            i++;
         }
      }
      json = { type = { FieldType::array }, a = array };
   }

   ~CQL2ExpArray()
   {
      delete elements;
      delete array;
   }
}

public class CQL2ExpInstance : CQL2Expression
{
   property bool printsAsMultiline
   {
      get
      {
         // NOTE: We do not want to resolve against arbitrary registered runtime classes (style sheet should be bound for output)
         Class type = expType ? expType : destType;
         if(!type || (type.type == structClass && strcmp(type.name, "HillShading") && strcmp(type.name, "StrokeStyling")) ||
            type.type == unitClass || type.type == bitClass ||
            (type.type == noHeadClass && strcmp(type.name, "Fill") && strcmp(type.name, "Stroke")))  // image.hotSpot currently doesn't get type set? -- bind needed
            return false;
         else
            return true;
      }
   }
public:
   CQL2Instantiation instance;
   InstanceMask targetMask;
   void * instData;
   ExpFlags instanceFlags;

   CQL2ExpInstance ::parse(CQL2SpecName spec, CQL2Lexer lexer)
   {
      return { instance = CQL2Instantiation::parse(spec, lexer) };
   }

   CQL2ExpInstance copy()
   {
      CQL2ExpInstance e
      {
         instance = instance ? instance.copy() : null,
         targetMask = targetMask, expType = expType, destType = destType
      };
      if(instData && instanceFlags == { resolved = true } && expType)
      {
         // Avoid re-computation of resolved instance
         void (* onCopy)(void *, void *, void *) = expType._vTbl[__eCVMethodID_class_OnCopy];
         if(expType.type == structClass)
         {
            e.instData = new0 byte[expType.structSize];
            onCopy(expType, e.instData, instData);
            e.instanceFlags = instanceFlags;
         }
      }
      return e;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      if(instance)
      {
         Class type = expType ? expType : destType;
         if(!type && instance._class && instance._class.name)
            type = eSystem_FindClass(__thisModule, instance._class.name);
         if(type)
         {
            if(type.type == structClass &&
               (type == class(Color) || type == class(Pointd) ||
                !strcmp(type.name, "ValueColor") || !strcmp(type.name, "ValueOpacity")))
               o.skipImpliedID = true;
            else if(type.type == bitClass)
               o.skipImpliedID = true;
         }
         o.multiLineInstance = printsAsMultiline;
         instance.print(out, indent, o);
      }
   }

   ExpFlags compute(FieldValue value, CQL2Evaluator evaluator, ComputeType computeType, Class instClass)
   {
      ExpFlags flags = 0; //can an instance be resolved entirely to a constant? -- we resolve it to a 'blob' FieldValue

      if(computeType == preprocessing && (!instData || instanceFlags != { resolved = true }))
      {
         Class c = evaluator.evaluatorClass.getClassFromInst(instance, destType, &instClass);
         int memberID = 0;

         if(instance)
         {
            for(inst : instance.members)
            {
               CQL2MemberInitList member = inst;
               for(m : member)
               {
                  CQL2MemberInit mInit = m;
                  flags |= mInit.precompute(instClass, c, targetMask, &memberID, evaluator);
               }
            }
         }
         if(flags.resolved && c && c.type == bitClass)
         {
            value.type = { integer };
            value.i = 0;
            setGenericBitMembers(this, (uint64 *)&value.i, evaluator, &flags, instClass);
         }
         else
            value = { { nil } };
         expType = c;

         instanceFlags = flags;
      }
      else if(computeType == runtime)
      {
         // REVIEW: Not re-computing if no extra flag is set -- does this only happen with literal instances?
         if(instData && (instanceFlags != { resolved = true } || instanceFlags.isNotLiteral))
         {
            if(expType && expType.type != structClass)
            {
               if(expType.type != noHeadClass) // TOCHECK: No ref count, likely deleted elsewhere
                  eInstance_DecRef(instData);
               else
               {
                  if(expType.Destructor)
                     expType.Destructor(instData);
                  eSystem_Delete(instData);
               }
               instData = null;
            }
            else if(expType && expType.type == structClass)
            {
               const void (* onFree)(void *, void *) = expType._vTbl[__eCVMethodID_class_OnFree];
               onFree(expType, instData);
               delete instData;
            }
            else
               delete instData;
         }

         if(instData)
            flags = instanceFlags;
         else
         {
            instData = evaluator.evaluatorClass.computeInstance(evaluator, instance, destType, &flags, &expType);
            instanceFlags = flags;
         }

         if((expType && expType == class(DateTime)) && instData && expType.type == structClass)
         {
            //FieldTypeEx fType { integer, isDateTime = true };
            DateTime dt = *(DateTime *)instData;
            //DateTime dateTime = *dt;
            value = { { integer, isDateTime = true }, i = (int64)(SecSince1970)dt };
            //value.type = fType;
         }
         else if(expType && (expType.type == unitClass || expType.type == bitClass))
         {
            value = destType == class(Color) ? { { integer, format = color } } : { { nil } };
            for(i : instance.members)
            {
               CQL2MemberInitList members = i;
               for(m : members)
               {
                  CQL2MemberInit mInit = m;
                  if(mInit.initializer)
                  {
                     CQL2Expression exp = mInit.initializer;
                     if(destType == class(Color))
                     {
                        FieldValue val {};
                        CQL2ExpIdentifier idExp = mInit.lhValue && mInit.lhValue._class == class(CQL2ExpIdentifier) ?
                           (CQL2ExpIdentifier)mInit.lhValue : null;
                        CQL2Identifier id = idExp ? idExp.identifier : null;
                        String s = id ? id.string : null;
                        Color col = (Color)value.i;
                        flags |= exp.compute(val, evaluator, runtime, instClass);
                        if(s)
                        {
                           if(!strcmp(s, "r"))
                              col.r = (byte)Min(Max(val.i,0),255);
                           else if(!strcmp(s, "g"))
                              col.g = (byte)Min(Max(val.i,0),255);
                           else if(!strcmp(s, "b"))
                              col.b = (byte)Min(Max(val.i,0),255);
                        }
                        value.i = col;
                     }
                     else
                        flags |= exp.compute(value, evaluator, runtime, instClass);
                  }
               }
            }
         }
         else if(!expType || expType != class(DateTime))
            value = { { blob }, b = instData };
         else if(!instData)
            value = { { nil } };
      }
      return flags;
   }

   void setMemberValue(const String idsString, InstanceMask mask, bool createSubInstance, const FieldValue value, Class c)
   {
      setMember2(idsString, mask, createSubInstance, expressionFromValue(value, c), null, null, none);
   }

   void setMemberValue2(const String idsString, InstanceMask mask, bool createSubInstance, const FieldValue value, Class c, CQL2Evaluator evaluator, Class instClass)
   {
      setMember2(idsString, mask, createSubInstance, expressionFromValue(value, c), evaluator, instClass, none);
   }

   void setMember(const String idsString, InstanceMask mask, bool createSubInstance, CQL2Expression expression)
   {
      setMember2(idsString, mask, createSubInstance, expression, null, null, none);
   }

   void setMember2(const String idsString, InstanceMask mask, bool createSubInstance, CQL2Expression expression, CQL2Evaluator evaluator, Class instClass, CQL2TokenType tt)
   {
      #ifdef _DEBUG
         if(!expression)
            PrintLn("WARNING: Null expression passed to setMember()");
      #endif

      if(this && idsString && idsString[0])
      {
         bool placed = false;
         if(instance && instance.members)
         {
            Iterator<CQL2MemberInitList> it { (void *)instance.members.list };

            it.Prev();
            while(it.pointer)
            {
               IteratorPointer prev = it.container.GetPrev(it.pointer);
               CQL2MemberInitList im = it.data;
               if(im)
               {
                  if(!placed && im.setSubMember(createSubInstance, expType, idsString, mask, expression, null, evaluator, instClass, none))
                     placed = true;
                  else
                  {
                     IteratorPointer after = null;

                     if(im.removeByIDs(idsString, mask, &after) && !placed)
                     {
                        CQL2MemberInit mInit;
                        CQL2MemberInitList::setSubMember(null, createSubInstance, expType, idsString, mask, expression, &mInit, evaluator, instClass, none);
                        im.Insert(after, mInit);
                        placed = true;
                     }
                     if(im && !im.GetCount())
                     {
                        delete im;
                        it.Remove();
                     }
                  }
               }
               it.pointer = prev;
            }
         }
         else
         {
            if(!instance) instance = { };
            if(!instance.members) instance.members = { };
         }

         if(!placed)
         {
            CQL2MemberInitList initList = strchr(idsString, '.') ? null : instance.members.lastIterator.data;
            if(!initList)
               instance.members.Add((initList = { }));
            initList.setMember2(expType, idsString, mask, createSubInstance, expression, evaluator, instClass, tt);
            instance.members.mask |= mask;
         }
      }
   }

   public CQL2Expression getMemberByIDs(Container<const String> ids)
   {
      CQL2Expression result = null;
      if(this && this._class == class(CQL2ExpInstance))
      {
         CQL2ExpInstance ei = (CQL2ExpInstance)this;
         if(ei.instance && ei.instance.members)
         {
            for(m : ei.instance.members)
            {
               CQL2MemberInitList members = m;
               if(members)
               {
                  CQL2Expression r = members.getMemberByIDs(ids);
                  if(r)
                     result = r;
               }
            }
         }
      }
      return result;
   }

   void toCQL2JSON(FieldValue json)
   {
      if(instance)
      {
         const String name = instance._class ? instance._class.name : null;
         bool isArray = false;

         if(destType &&
            (!strcmp(destType, "ValueColor") ||
             !strcmp(destType, "Color") ||
             !strcmp(destType, "GeoPoint")))
             isArray = true;

         {
            Map<String, FieldValue> map = null;
            Array<FieldValue> args = null;
            bool isValueColor = isArray && !strcmp(destType, "ValueColor");

            if(name && !isArray)
            {
               map = { };
               args = { };
               json = { type = { FieldType::map }, m = map };
               map["op"] = FieldValue { type = { text, mustFree = true }, s = CopyString(name) };
               map["args" ] = FieldValue { type = { array }, a = args };
            }
            else if(!isArray)
            {
               map = { };
               json = { type = { FieldType::map }, m = map };
            }
            else
            {
               args = { };
               json = { type = { array }, a = args };
            }

            if(instance.members)
            {
               for(m : instance.members)
               {
                  CQL2MemberInitList initList = m;

                  if(initList)
                  {
                     for(mm : initList)
                     {
                        // TODO: Full instance support for CartoSym
                        CQL2MemberInit init = mm;
                        CQL2Expression k = init.lhValue;

                        if(init.initializer)
                        {
                           FieldValue a { };

                           init.initializer.toCQL2JSON(a);

                           if(args)
                           {
                              args.Add(a);

                              // REVIEW: Special handling of ValueColor which is currently used as a single tuple in CartoSym-CSS input
                              if(isValueColor)
                              {
                                 Array<FieldValue> colorArgs { };
                                 args.Add({ type = { array }, a = colorArgs });
                                 args = colorArgs;
                                 isValueColor = false;
                              }
                           }
                           else
                           {
                              const String s = null;
                              if(k && k._class == class(CQL2ExpIdentifier))
                              {
                                 CQL2ExpIdentifier expId = (CQL2ExpIdentifier)k;
                                 s = expId.identifier ? expId.identifier.string : null;
                              }
                              if(s)
                                 map[s] = a;
                           }
                        }
                     }
                  }
               }
            }
         }
      }
      else
         json = { type = { nil } };
   }

   ~CQL2ExpInstance()
   {
      delete instance;

      if(instData)
      {
         if(expType && expType.type != structClass)
         {
            if(expType.type != noHeadClass) // TOCHECK: No ref count, likely deleted elsewhere
               eInstance_DecRef(instData);
            else
            {
               if(expType.Destructor)
                  expType.Destructor(instData);
               eSystem_Delete(instData);
            }
         }
         else if(expType && expType.type == structClass)
         {
            const void (* onFree)(void *, void *) = expType._vTbl[__eCVMethodID_class_OnFree];
            onFree(expType, instData);
            delete instData;
         }
         else
            delete instData;
      }
   }
}

// This is a semi-colon separated list
public class CQL2InstInitList : CQL2List<CQL2MemberInitList>
{
public:
   InstanceMask mask;

   CQL2InstInitList ::parse(CQL2Lexer lexer)
   {
      return (CQL2InstInitList)CQL2List::parse(class(CQL2InstInitList), lexer, CQL2MemberInitList::parse, 0);
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      Iterator<CQL2MemberInitList> it { list };
      while(it.Next())
      {
         CQL2MemberInitList initList = it.data;
         initList.print(out, indent, o);
         if(list.GetNext(it.pointer))
         {
            if(o.multiLineInstance)
            {
               out.PrintLn(";");
               printIndent(indent, out);
            }
            else
               out.Print(", ");
         }
      }

      // CQL2List::print(out, indent, o);
   }

   // getProperty2() is same as getProperty() but splits up the unit value and unit (e.g. Meters) separately
   CQL2Expression getProperty2(InstanceMask msk, Class * uc)
   {
      CQL2Expression result = getProperty(msk);
      while(result && result._class == class(CQL2ExpInstance))
      {
         CQL2ExpInstance ei = (CQL2ExpInstance)result;

         if(uc && ei.instance && ei.instance._class)
         {
            CQL2SpecName sn = (CQL2SpecName)ei.instance._class;
            Class c = sn ? eSystem_FindClass(__thisModule, sn.name) : null;
            if(c && c.type == unitClass && c.base.type == unitClass)
            {
               *uc = c;
               msk = 0;
               break;
            }
         }
         else
            result = null;

         if(ei.instance && ei.instance.members)
         {
            result = null;

            // NOTE: This piece and the while loop should no longer be required now with findDeepProperty()
            // TODO: Should iterate from the last?
            for(i : ei.instance.members)
            {
               CQL2MemberInitList members = i;
               CQL2MemberInit mInit = members ? members.findDeepProperty(msk) : null;
               if(mInit)
               {
                  result = mInit.initializer;
                  break;
               }
            }
         }
         else
            break;
      }
      return result;
   }

   CQL2MemberInit findProperty(InstanceMask msk)
   {
      // if(mask & this.mask)
      {
         Iterator<CQL2MemberInitList> it { this };
         while(it.Prev())
         {
            CQL2MemberInitList e = it.data;
            CQL2MemberInit mInit = e.findProperty(msk);
            if(mInit) return mInit;
         }
      }
      return null;
   }

   CQL2MemberInit findDeepProperty(InstanceMask msk)
   {
      // if(mask & this.mask)
      {
         Iterator<CQL2MemberInitList> it { this };
         while(it.Prev())
         {
            CQL2MemberInitList e = it.data;
            CQL2MemberInit mInit = e.findDeepProperty(msk);
            if(mInit) return mInit;
         }
      }
      return null;
   }

   void removeProperty(InstanceMask msk)
   {
      Iterator<CQL2MemberInitList> it { this };
      it.Next();
      while(it.pointer)
      {
         IteratorPointer next = it.container.GetNext(it.pointer);
         CQL2MemberInitList memberInitList = it.data;
         memberInitList.removeProperty(msk);
         if(memberInitList.GetCount() == 0)
         {
            it.Remove();
            delete memberInitList;
         }
         it.pointer = next;
      }
      mask &= ~msk; // todo: make sure this is ok or write a mask recalculation function?
   }

   CQL2Expression getProperty(InstanceMask mask)
   {
      CQL2MemberInit mInit = findDeepProperty(mask);
      return mInit ? mInit.initializer : null;
   }

   void setMemberValue(Class c, const String idsString, InstanceMask mask, bool createSubInstance, const FieldValue value, Class uc)
   {
      setMember2(c, idsString, mask, createSubInstance, expressionFromValue(value, uc), null, null, none);
   }

   void setMemberValue2(Class c, const String idsString, InstanceMask mask, bool createSubInstance, const FieldValue value, Class uc, CQL2Evaluator evaluator, Class instClass)
   {
      setMember2(c, idsString, mask, createSubInstance, expressionFromValue(value, uc), evaluator, instClass, none);
   }

   void setMember(Class c, const String idString, InstanceMask msk, bool createSubInstance, CQL2Expression expression)
   {
      if(expression)
         setMember2(c, idString, msk, createSubInstance, expression, null, null, none);
      else
         removeProperty(msk); // TOCHECK: Should the style be removed if attempting to set a null expression?
   }

   void setMember2(Class c, const String idString, InstanceMask msk, bool createSubInstance, CQL2Expression expression, CQL2Evaluator evaluator, Class instClass, CQL2TokenType tt)
   {
      if(this)
      {
         CQL2MemberInitList list = null;
         if(msk)
         {
            Iterator<CQL2MemberInitList> it { this };
            char * dot = idString ? strchr(idString, '.') : null;
            String member = null;
            if(dot)
            {
               int len = (int)(dot - idString);
               member = new char[len+1];
               memcpy(member, idString, len);
               member[len] = 0;
            }

            /*InstanceMask topMask = msk;
            char * pch = strchr(idString, '.');
            if(pch)
            {
               int size = pch ? ((int)(pch - idString)) + 1 : 0;
               if(size)
               {
                  String prefix = new char[size];
                  memcpy(prefix, idString, size - 1);
                  prefix[size - 1] = '\0';
                  topMask = evaluator.evaluatorClass.maskFromString(prefix, c);
                  delete prefix;
               }
            }*/

            while(it.Prev())
            {
               CQL2MemberInitList members = it.data;
               if(member && members.findTopStyle(mask, member))
               {
                  list = members;
                  break;
               }

               if(members.findProperty(msk))
               {
                  list = members;
                  break;
               }
            }
            delete member;
         }
         if(!list)
            Add((list = { }));

         list.setMember2(c, idString, msk, createSubInstance, expression, evaluator, instClass, tt);

         mask |= msk;
      }
   }

   bool changeProperty(InstanceMask msk, const FieldValue value, Class c, CQL2Evaluator evaluator, bool isNested, Class uc)
   {
      const String idString = msk ? evaluator.evaluatorClass.stringFromMask(msk, c) : null;
      CQL2Expression e = expressionFromValue(value, uc);
      FieldValue v { };

      setMember2(c, idString, msk, !isNested, e, evaluator, c, none);
      e.compute(v, evaluator, preprocessing, c); // REVIEW: use of c for instClass here...
      return true;
   }
}

public class CQL2Instantiation : CQL2Node
{
public:
   CQL2SpecName _class;

   CQL2InstInitList members;

   CQL2Instantiation ::parse(CQL2SpecName spec, CQL2Lexer lexer)
   {
      CQL2Instantiation inst { _class = spec };
      lexer.readToken();
      inst.members = CQL2InstInitList::parse(lexer);

      if(lexer.peekToken().type == '}' || lexer.peekToken().type == ')')
         lexer.readToken();
      return inst;
   }

   CQL2Instantiation copy()
   {
      CQL2Instantiation o { _class = _class ? _class.copy() : null, members = members ? members.copy() : null };
      return o;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      bool multiLine = o.multiLineInstance;

      if(_class) { _class.print(out, indent, o); if(!multiLine) out.Print(" "); }
      if(multiLine)
      {
         out.PrintLn("");
         printIndent(indent, out);
      }
      out.Print("{");
      if(multiLine)
      {
         out.PrintLn("");
         indent++;
      }
      if(members && members[0])
      {
         if(multiLine)
         {
            Iterator<CQL2MemberInitList> it { members };
            while(it.Next())
            {
               CQL2MemberInitList init = it.data;
               printIndent(indent, out);
               init.print(out, indent, o);
               // REVIEW: When we want this semicolon?
               if(init._class == class(CQL2MemberInitList) && members.GetNext(it.pointer))
                  out.Print(";");
               out.PrintLn("");
            }
         }
         else
         {
            out.Print(" ");
            members.print(out, indent, o);
            out.Print(" ");
         }
      }
      else if(!multiLine)
         out.Print(" ");
      if(multiLine)
      {
         indent--;
         printIndent(indent, out);
      }
      out.Print("}");
   }


   ~CQL2Instantiation()
   {
      delete _class;

      delete members;
   }
};

public class CQL2MemberInit : CQL2Node
{
   class_no_expansion;
public:
   CQL2Expression lhValue;
   CQL2Expression initializer;

   CQL2TokenType assignType;
   Class destType;
   InstanceMask stylesMask;
   DataMember dataMember;
   uint offset;

   CQL2MemberInit ::parse(CQL2Lexer lexer)
   {
      CQL2Expression lhValue = null;
      CQL2Expression initializer = null;
      CQL2TokenType assignType = '=';
      if(lexer.peekToken().type == identifier)
      {
         int a = lexer.pushAmbiguity();
         lhValue = CQL2ExpIdentifier::parse(lexer);
         if(lhValue)
         {
            while(true)
            {
               CQL2Token token = lexer.peekToken();
               if(token.type == '.')
               {
                  lexer.readToken();
                  token = lexer.peekToken();
                  if(token.type == identifier)
                  {
                     CQL2Identifier id = CQL2Identifier::parse(lexer);
                     lhValue = CQL2ExpMember { exp = lhValue, member = id };
                  }
                  else
                     break;
               }
               else if(token.type == '[')
               {
                  CQL2Expression index;

                  lexer.readToken();
                  index = CQL2Expression::parse(lexer);
                  if(index && lexer.peekToken().type == ']')
                  {
                     lexer.readToken();
                     lhValue = CQL2ExpIndex { exp = lhValue, index = CQL2ExpList { [ index ] } };
                  }
                  else
                     break;
               }
               else
                  break;
            }
         }
         if(lhValue && (lexer.peekToken().type == ':' || lexer.nextToken.type == addAssign))
         {
            assignType = lexer.nextToken.type == addAssign ? addAssign : equal;
            lexer.clearAmbiguity();
            lexer.readToken();
         }
         else
         {
            delete lhValue;
            lexer.popAmbiguity(a);
         }
      }
      initializer = CQL2Expression::parse(lexer);  /*CSInitExp*/
      return (lhValue || initializer) ?
         CQL2MemberInit { lhValue = lhValue, initializer = initializer, assignType = assignType } : null;
   }

   CQL2Node copy()
   {
      CQL2MemberInit memberInit
      {
         assignType = assignType, initializer = initializer.copy(), stylesMask = stylesMask,
         lhValue = lhValue.copy(),
         destType = destType, dataMember = dataMember,
         offset = offset
      };
      return memberInit;
   }

   static Class ::resolveLH(CQL2Expression lh, Class type, DataMember * dataMember)
   {
      Class resultType = null;
      const String memberID = null;

      if(lh._class == class(CQL2ExpMember))
      {
         CQL2ExpMember expMember = (CQL2ExpMember)lh;

         if(expMember.exp && expMember.member && expMember.member.string)
         {
            type = resolveLH(expMember.exp, type, dataMember);
            memberID = expMember.member.string;
         }
      }
      else if(lh._class == class(CQL2ExpIdentifier))
      {
         CQL2ExpIdentifier expId = (CQL2ExpIdentifier)lh;
         memberID = expId.identifier ? expId.identifier.string : null;
      }
      else if(lh._class == class(CQL2ExpIndex))
      {
         // TODO: CQL2ExpIndex expIndex = (CQL2ExpIndex)lh;
      }
      if(memberID)
      {
         const String dot = memberID ? strstr(memberID, ".") : null;
         if(dot)
         {
            Array<String> split = splitIdentifier(memberID);
            for(s : split)
            {
               const String idPart = s;
               if(type)
               {
                  *dataMember = eClass_FindDataMember(type, idPart, type.module, null, null);
                  if(!*dataMember)
                  {
                     *dataMember = (DataMember)eClass_FindProperty(type, idPart, type.module);
                  }
                  if(*dataMember)
                  {
                     if(!dataMember->dataTypeClass)
                        dataMember->dataTypeClass = type =
                           eSystem_FindClass(dataMember->_class.module, dataMember->dataTypeString);
                     else
                        type = dataMember->dataTypeClass;
                  }
                  else
                     type = null;
               }
            }
            delete split;
         }
         else
         {
            *dataMember = eClass_FindDataMember(type, memberID, type.module, null, null);
            if(!*dataMember)
            {
               *dataMember = (DataMember)eClass_FindProperty(type, memberID, type.module);
            }
         }
         if(*dataMember)
         {
            if(!dataMember->dataTypeClass)
               dataMember->dataTypeClass = eSystem_FindClass(dataMember->_class.module, dataMember->dataTypeString);
            resultType = dataMember->dataTypeClass;
         }
      }
      return resultType;
   }


   // targetStylesMask is topMask for the 'c' instance (e.g. stroke for stroke =)
   /*private */ExpFlags precompute(Class instClass, Class c, InstanceMask targetStylesMask, int * memberID, CQL2Evaluator evaluator)
   {
      ExpFlags flags = 0;
      // NOTE: We need a separate Class for the styling object within which a sub-instance would be
      //       vs. the current instance level class (current c)
      String identifierStr = targetStylesMask ? CopyString(evaluator.evaluatorClass.stringFromMask(targetStylesMask, instClass)) : null;
      Class type = c;
      DataMember dataMember = null;

      if(type && lhValue)
      {
         String v = lhValue.toString(0);
         if(identifierStr)
         {
            String s = PrintString(identifierStr, ".", v);
            delete identifierStr;
            identifierStr = s;
            delete v;
         }
         else
            identifierStr = v;

         destType = type = resolveLH(lhValue, type, &dataMember);
      }
      else if(memberID)
      {
         //want the member from label's inherited MGE here
         Class baseClass;
         Array<Class> bases { };
         int mid = 0;
         for(baseClass = c; baseClass; baseClass = baseClass.inheritanceAccess == publicAccess ? baseClass.base : null)
         {
            if(baseClass.isInstanceClass || !baseClass.base)
               break;
            bases.Insert(null, baseClass);
         }

         for(baseClass : bases)
         {
            for(dataMember = baseClass.membersAndProperties.first; dataMember; dataMember = dataMember.next)
            {
               if(dataMember.memberAccess == publicAccess)
               {
                  if(mid == *memberID)
                     break;
                  mid++;
               }
            }
            if(dataMember)
            {
               String s = identifierStr ? PrintString(identifierStr, ".", dataMember.name) : CopyString(dataMember.name);
               delete identifierStr;
               identifierStr = s;

               if(!dataMember.dataTypeClass)
                  dataMember.dataTypeClass = destType = eSystem_FindClass(dataMember._class.module, dataMember.dataTypeString);
               else
                  destType = dataMember.dataTypeClass;
               (*memberID)++;

               if(destType && destType.templateClass)
               {
                  bool replace = false;
                  int i=0;
                  char templateName[2048];
                  strcpy(templateName, destType.templateClass.name);
                  strcat(templateName, "<");
                  for(i=0; i < destType.numParams; i++)
                  {
                     ClassTemplateArgument arg = destType.templateArgs[i];
                     if(i != 0)
                        strcat(templateName, ", ");
                     if(!arg.dataTypeClass)
                     {
                        Class bc; // Geom
                        bool found = false;
                        int j = 0;
                        for(bc = type; bc; bc = bc.inheritanceAccess == publicAccess ? bc.base : null)
                        {
                           ClassTemplateParameter param;
                           j = 0;
                           for(param = bc.templateParams.first; param; param = param.next)
                           {
                              if(param.type == TemplateParameterType::type && !strcmp(param.name, arg.dataTypeString))
                                 break;
                              j++;
                           }
                           if(param)
                           {
                              Class bc2;
                              for(bc2 = bc.base; bc2; bc2 = bc2.base)
                                 j += bc2.templateParams.count;
                              found = true;
                              break;
                           }
                        }
                        if(found)
                        {
                           strcat(templateName, type.templateArgs[j].dataTypeString);
                           replace = true;
                        }
                        else
                           strcat(templateName, arg.dataTypeString);
                     }
                     else //NOTE: should also use param for this loop... if(param.)
                        strcat(templateName, arg.dataTypeString);
                  }
                  if(replace)
                  {
                     strcat(templateName, ">");
                     destType = eSystem_FindClass(type.module, templateName);
                  }
               }
               break; //?
            }
         }
         delete bases;
      }

      if(dataMember)
      {
         if(!dataMember.isProperty)
         {
            eClass_FindDataMemberAndOffset(dataMember._class, dataMember.name, &offset, dataMember._class.module, null, null);
            offset = computeMemberOffset(dataMember, offset);
         }
         this.dataMember = dataMember;

         stylesMask = identifierStr && instClass && instClass.type != structClass && destType != class(byte)
            ? evaluator.evaluatorClass.maskFromString(identifierStr, instClass) : 0;
         if(initializer)
         {
            CQL2Expression e = initializer;
            if(e)
            {
               FieldValue val { };
               e.destType = destType;

               if(assignType == addAssign && destType && eClass_IsDerived(destType, class(Container)))
               {
                  ClassTemplateArgument a = destType.templateArgs[0];
                  Class dtc = a.dataTypeClass;
                  e.destType = dtc;
                  flags = e.compute(val, evaluator, preprocessing, null);
               }
               else
               {
                  if(e._class == class(CQL2ExpInstance))
                  {
                     ((CQL2ExpInstance)e).targetMask = stylesMask;
                  }
                  else if(e._class == class(CQL2ExpConditional))
                  {
                     CQL2ExpConditional cond = (CQL2ExpConditional)e;
                     CQL2Expression lastExp = cond.expList ? cond.expList.lastIterator.data : null;
                     if(lastExp && lastExp._class == class(CQL2ExpInstance))
                     {
                        ((CQL2ExpInstance)lastExp).targetMask = stylesMask;
                     }
                     if(cond.elseExp && cond.elseExp._class == class(CQL2ExpInstance))
                     {
                        ((CQL2ExpInstance)cond.elseExp).targetMask = stylesMask;
                     }
                  }
                  flags = e.compute(val, evaluator, preprocessing, instClass);
               }
               if(flags.resolved)
                  initializer = simplifyResolved(val, e);
            }
         }
      }
      else if(type && type.type == unitClass)
      {
         stylesMask = identifierStr && instClass && instClass.type != structClass
            ? evaluator.evaluatorClass.maskFromString(identifierStr, instClass) : 0;
         if(initializer)
         {
            CQL2Expression e = initializer;
            if(e)
            {
               FieldValue val { };
               e.destType = type;
               if(e._class == class(CQL2ExpInstance))
                  ((CQL2ExpInstance)e).targetMask = stylesMask;
               flags = e.compute(val, evaluator, preprocessing, instClass);
               if(flags.resolved)
                  initializer = simplifyResolved(val, e);
            }
         }
      }
      delete identifierStr;
      return flags;
   }

   uint computeMemberOffset(DataMember dataMember, uint offset)
   {
      if(dataMember._class.type == normalClass || dataMember._class.type == noHeadClass)
      {
         int add = dataMember._class.base.structSize;
         if( dataMember._class.structAlignment && dataMember._class.base.structSize % dataMember._class.structAlignment) //Don't do mod 0
            add += dataMember._class.structAlignment - dataMember._class.base.structSize % dataMember._class.structAlignment;
         offset += add;
      }
      return offset;
      //destType == class(int64)  .. destType == class(double)
   }

   void printSep(File out)
   {
      out.PrintLn(";");
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      print2(out, indent, o, null);
   }

   void print2(File out, int indent, CQL2OutputOptions o, DataMember lastMember)
   {
      bool outputIdentifiers = false;
      if(lhValue)
      {
         outputIdentifiers = true;
         if(lhValue._class == class(CQL2ExpIdentifier) && o.skipImpliedID && dataMember)
         {
            if((!lastMember && dataMember.id == 0) || (lastMember && dataMember.id == lastMember.id + 1))
               outputIdentifiers = false;
         }
      }

      if(outputIdentifiers)
      {
         CQL2ExpInstance ei = initializer && initializer._class == class(CQL2ExpInstance) ? (CQL2ExpInstance)initializer : null;
         Class type = ei ? (ei.expType ? ei.expType : ei.destType) : null;
         bool slType = !type || type.type == structClass || type.type == unitClass || type.type == bitClass || type.type == noHeadClass;

         if(type && type.type == structClass && !strcmp(type.name, "HillShading")) // Make an exception until we switch to noHeadClass
            slType = false;

         if(lhValue)
            lhValue.print(out, indent, o);

         if(assignType == equal)
            CQL2TokenType::colon.print(out, indent, o);
         else
         {
            out.Print(" ");
            assignType.print(out, indent, o);
         }
         if(slType && (!initializer || initializer._class != class(CQL2ExpInstance) || !((CQL2ExpInstance)initializer).printsAsMultiline))
            out.Print(" "); // Not multiline
         else if(assignType == addAssign)
         {
            out.PrintLn("");
            printIndent(indent, out);
         }
      }
      if(initializer)
         initializer.print(out, indent, o);
   }

   ~CQL2MemberInit()
   {
      delete lhValue;
      delete initializer;
   }
};

// This is a comma-separated list
public class CQL2MemberInitList : CQL2List<CQL2MemberInit>
{
public:
   //InstanceMask stylesMask;
   CQL2MemberInitList ::parse(CQL2Lexer lexer)
   {
      CQL2MemberInitList list = (CQL2MemberInitList)CQL2List::parse(class(CQL2MemberInitList), lexer, CQL2MemberInit::parse, ',');
      if(lexer.peekToken().type == ';')
         lexer.readToken();
      return list;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      Iterator<CQL2MemberInit> it { list };
      DataMember lastMember = null;
      while(it.Next())
      {
         CQL2MemberInit init = it.data;
         init.print2(out, indent, o, lastMember);
         lastMember = init.dataMember;
         if(list.GetNext(it.pointer))
         {
            // NOTE: can multiLineInstance keep 'true' from call to CQL2ExpInstance::print?
            if(o.multiLineInstance || init.assignType == addAssign)
            {
               out.PrintLn(";");
               printIndent(indent, out);
            }
            else
               printSep(out);
         }
      }
   }

   CQL2Expression getMemberByIDs(Container<const String> ids)
   {
      return getMemberByIDs2(ids, null);
   }

   // Returns true for same
   static bool lhValueSameAsIDs(CQL2Expression leftHand, Container<const String> ids)
   {
      bool same = true;
      CQL2Expression lh = leftHand;
      int count = lh ? 1 : 0;

      while(lh && lh._class == class(CQL2ExpMember))
      {
         lh = ((CQL2ExpMember)lh).exp;
      }

      if(ids.GetCount() != count)
         same = false;
      else
      {
         int j;

         lh = leftHand;
         for(j = ids.GetCount()-1; j >= 0; j--)
         {
            const String id = ids[j];

            if(lh && id)
            {
               if(lh._class == class(CQL2ExpMember))
               {
                  CQL2ExpMember expMember = (CQL2ExpMember)lh;
                  const String s = expMember.member ? expMember.member.string : null;
                  if(!s || strcmp(s, id))
                  {
                     same = false;
                     break;
                  }
                  lh = expMember.exp;
               }
               else if(lh._class == class(CQL2ExpIdentifier))
               {
                  CQL2ExpIdentifier expId = (CQL2ExpIdentifier)lh;
                  const String s = expId.identifier ? expId.identifier.string : null;
                  if(!s || strcmp(s, id))
                  {
                     same = false;
                     break;
                  }
                  lh = null;
               }
               else
               {
                  same = false;
                  break;
               }
            }
            else
            {
               same = false;
               break;
            }
         }
      }
      return same;
   }

   CQL2Expression getMemberByIDs2(Container<const String> ids, CQL2MemberInit * initPtr)
   {
      CQL2Expression result = null;
      // TODO: Recognize default initializers
      for(mi : this)
      {
         CQL2MemberInit init = mi;
         CQL2Expression initializer = init ? init.initializer : null;
         if(initializer)
         {
            bool same = lhValueSameAsIDs(init.lhValue, ids);
            if(same)
            {
               result = initializer;
               if(initPtr) *initPtr = init;
            }
         }
      }
      return result;
   }

   private static bool setSubMember(bool createSubInstance, Class c, const String idsString, InstanceMask mask, CQL2Expression expression,
      CQL2MemberInit * mInitPtr, CQL2Evaluator evaluator, Class instClass, CQL2TokenType tt)
   {
      CQL2MemberInit mInit = null;
      CQL2MemberInit mInit2 = null;
      bool setSubInstance = false;

      if(idsString && idsString[0])
      {
         char * dot = strchr(idsString, '.');
         String member = null;
         if(dot)
         {
            int len = (int)(dot - idsString);
            CQL2Expression e = null;

            member = new char[len+1];

            memcpy(member, idsString, len);
            member[len] = 0;

            if(this && tt != addAssign) //
            {
               e = getMemberByIDs2([ member ], &mInit2); // TOCHECK: Is this still needed?
               if(!e && mask)
               {
                  // This will recognize default initializers...
                  CQL2MemberInit mInit = findTopStyle(mask, member);
                  if(mInit) e = mInit.initializer;

                  if(!e)
                  {
                     // If we don't have the parent instance set, look for the exact style directly set
                     mInit = findExactStyle(mask);
                     if(mInit)
                     {
                        // We simply replace the expression
                        delete mInit.initializer;
                        mInit.initializer = e = expression;
                        if(expression && mInit.destType) expression.destType = mInit.destType;
                        setSubInstance = true;
                     }

                     if(!e)
                     {
                        // Direct style isn't set, look for any intermediate style
                        mInit = findProperty(mask);
                        if(mInit) e = mInit.initializer;
                     }
                  }
               }
            }

            if(!e && createSubInstance)
            {
               e = CQL2ExpInstance { };
               if(evaluator != null)
               {
                  // NOTE: If we have the evaluator here, we can set targetMask for ExpInstance, as we should...
                  ((CQL2ExpInstance)e).targetMask = evaluator.evaluatorClass.maskFromString(member, instClass);
               }
               if(c)
               {
                  DataMember dataMember = eClass_FindDataMember(c, member, c.module, null, null);
                  if(!dataMember)
                  {
                     dataMember = (DataMember)eClass_FindProperty(c, member, c.module);
                  }
                  if(dataMember && !dataMember.dataTypeClass)
                     dataMember.dataTypeClass =
                        eSystem_FindClass(dataMember._class.module, dataMember.dataTypeString);
                  if(dataMember)
                     e.expType = dataMember.dataTypeClass;
               }

               ((CQL2ExpInstance)e).setMember(dot+1, mask, createSubInstance, expression);
               expression = e;
               idsString = member;
            }
            else if(e && e._class == class(CQL2ExpInstance) && !setSubInstance)
            {
               ((CQL2ExpInstance)e).setMember(dot+1, mask, createSubInstance, expression);
               setSubInstance = true;

               if(mInit2)
                  mInit2.stylesMask |= mask;
            }
         }

         if(!setSubInstance && mInitPtr)
         {
            // NOTE: The mask being set here should be the full mask if expression is a CQL2ExpInstance (but requires the targetMask to be set)
            if(expression && expression._class == class(CQL2ExpInstance))
            {
               mask |= ((CQL2ExpInstance)expression).targetMask;
            }

            mInit =
            {
               initializer = expression,
               // identifiers = { }, // FIXME: #1220
               assignType = tt == addAssign ? addAssign : equal,
               stylesMask = mask;
            };
            if(expression && mInit.destType) expression.destType = mInit.destType;

            if(dot)
            {
               Array<String> split = dot ? splitIdentifier(idsString) : { [ CopyString(idsString) ] };
               DataMember dataMember = null;
               for(s : split)
               {
                  if(mInit.lhValue)
                  {
                     mInit.lhValue = CQL2ExpMember { exp = mInit.lhValue, member = CQL2Identifier { string = s } };
                  }
                  else
                  {
                     mInit.lhValue = CQL2ExpIdentifier { identifier = CQL2Identifier { string = s } };
                  }
                  if(c)
                  {
                     dataMember = eClass_FindDataMember(c, s, c.module, null, null);
                     if(!dataMember)
                     {
                        dataMember = (DataMember)eClass_FindProperty(c, s, c.module);
                     }
                     if(dataMember)
                     {
                        if(!dataMember.dataTypeClass)
                           dataMember.dataTypeClass = c =
                              eSystem_FindClass(dataMember._class.module, dataMember.dataTypeString);
                        else
                           c = dataMember.dataTypeClass;
                     }
                     else
                        c = null;
                  }
               }
               mInit.dataMember = dataMember;
               expression.destType = mInit.destType = c;
               delete split;
            }
            else
            {
               if(c)
               {
                  mInit.dataMember = eClass_FindDataMember(c, idsString, c.module, null, null);
                  if(!mInit.dataMember)
                  {
                     mInit.dataMember = (DataMember)eClass_FindProperty(c, idsString, c.module);
                  }
                  if(mInit.dataMember)
                  {
                     if(!mInit.dataMember.dataTypeClass)
                        mInit.dataMember.dataTypeClass =
                           eSystem_FindClass(mInit.dataMember._class.module, mInit.dataMember.dataTypeString);
                     mInit.destType = mInit.dataMember.dataTypeClass;
                  }
                  if(expression)
                     expression.destType = mInit.destType;
               }
               mInit.lhValue = CQL2ExpIdentifier { identifier = { string = CopyString(idsString) } };
            }
         }
         delete member;
      }
      if(mInitPtr && !setSubInstance)
         *mInitPtr = mInit;
      return setSubInstance;
   }

   bool removeByIDs(const String idsString, InstanceMask mask, IteratorPointer * after)
   {
      bool result = false;
      char * dot = idsString ? strchr(idsString, '.') : null;
      Array<String> split = dot ? splitIdentifier(idsString ? idsString : "") : { [ CopyString(idsString) ] };
      Iterator<CQL2MemberInit> itmi { this };

      itmi.Next();
      while(itmi.pointer)
      {
         IteratorPointer next = GetNext(itmi.pointer);
         CQL2MemberInit oldMInit = itmi.data;
         bool same = true;

         if(oldMInit.lhValue && split.count)
            same = lhValueSameAsIDs(oldMInit.lhValue, (Container<const String>)split);
         else if((oldMInit.lhValue && !split.count) || (!oldMInit.lhValue && split.count))
         {
            if(!oldMInit.lhValue && split.count == 1 && mask && oldMInit.stylesMask == mask)
               ;
            else
               same = false;
         }

         if(same)
         {
            delete oldMInit;

            if(after) *after = GetPrev(itmi.pointer);
            itmi.Remove();
            result = true;
         }
         itmi.pointer = next;
      }
      split.Free();
      delete split;
      return result;
   }

   void setMember(Class c, const String idsString, InstanceMask mask, bool createSubInstance, CQL2Expression expression)
   {
      setMember2(c, idsString, mask, createSubInstance, expression, null, null, none);
   }

   void setMember2(Class c, const String idsString, InstanceMask mask, bool createSubInstance, CQL2Expression expression, CQL2Evaluator evaluator, Class instClass, CQL2TokenType tt)
   {
      CQL2MemberInit mInit;

      if(!setSubMember(createSubInstance, c, idsString, mask, expression, &mInit, evaluator, instClass, tt))
      {
         // Delete old values
         bool placed = false;
         IteratorPointer after;
         if(removeByIDs(idsString, mask, &after))
         {
            Insert(after, mInit);
            placed = true;
         }

         if(!placed)
            Add(mInit);
      }
   }

   // Returns any member init overriding this mask -- it could be at a different level and thus not exactly what is being requested
   CQL2MemberInit findProperty(InstanceMask mask)
   {
      //if(mask & stylesMask)
      {
         Iterator<CQL2MemberInit> it { this };
         while(it.Prev())
         {
            CQL2MemberInit mInit = it.data;
            InstanceMask sm = mInit.stylesMask;
            if(!mask || (sm & mask))   // NOTE: Useful to pass a 0 mask to look for unit class value
               return mInit;
         }
      }
      return null;
   }

   // Returns the top style matching topID requested, using sub-value mask to avoid unneeded comparisons
   CQL2MemberInit findTopStyle(InstanceMask mask, const String topID)
   {
      //if(mask & stylesMask)
      {
         Iterator<CQL2MemberInit> it { this };
         while(it.Prev())
         {
            CQL2MemberInit mInit = it.data;
            InstanceMask sm = mInit.stylesMask;
            if(sm & mask)   // NOTE: Useful to pass a 0 mask to look for unit class value
            {
               if(mInit && mInit.dataMember && !strcmp(mInit.dataMember.name, topID))
                  return mInit;
            }
         }
      }
      return null;
   }

   // Returns an expression set to exactly the requested map, directly at this level
   CQL2MemberInit findExactStyle(InstanceMask mask)
   {
      //if(mask & stylesMask)
      {
         Iterator<CQL2MemberInit> it { this };
         while(it.Prev())
         {
            CQL2MemberInit mInit = it.data;
            InstanceMask sm = mInit.stylesMask;
            if(sm == mask)
               return mInit;
         }
      }
      return null;
   }

   // Returns an expression exactly for requested mask, including from sub-instance, or null
   CQL2MemberInit findDeepProperty(InstanceMask mask)
   {
      //if(mask & stylesMask)
      {
         Iterator<CQL2MemberInit> it { this };
         while(it.Prev())
         {
            CQL2MemberInit mInit = it.data;
            InstanceMask sm = mInit.stylesMask;
            if(sm == mask)
               return mInit;
            else if(sm & mask)
            {
               if(mInit.initializer && mInit.initializer._class == class(CQL2ExpInstance))
               {
                  CQL2ExpInstance ei = (CQL2ExpInstance)mInit.initializer;
                  mInit = ei.instance && ei.instance.members ? ei.instance.members.findDeepProperty(mask) : null;
               }
               else
                  mInit = null;
               return mInit;
            }
         }
      }
      return null;
   }

   void removeProperty(InstanceMask mask)
   {
      Iterator<CQL2MemberInit> it { this };
      it.Next();
      while(it.pointer)
      {
         IteratorPointer next = it.container.GetNext(it.pointer);
         CQL2MemberInit memberInit = it.data;
         if(memberInit.stylesMask & mask)
         {
            if((memberInit.stylesMask & mask) == memberInit.stylesMask)
            {
               it.Remove();
               delete memberInit;
            }
            else
            {
               CQL2Expression e = memberInit.initializer;
               if(e._class == class(CQL2ExpInstance))
               {
                  CQL2ExpInstance inst = (CQL2ExpInstance)e;
                  // FIXME: stylesMask is not always set after a changeProperty() ?  if(inst.stylesMask & mask)
                  {
                     CQL2InstInitList initList = inst.instance ? inst.instance.members : null;
                     if(initList)
                     {
                        Iterator<CQL2MemberInitList> itl { initList };
                        itl.Next();
                        while(itl.pointer)
                        {
                           IteratorPointer nextL = itl.container.GetNext(itl.pointer);
                           CQL2MemberInitList mInitList = itl.data;
                           if(mInitList)
                           {
                              mInitList.removeProperty(mask);
                              if(!mInitList.list.first)
                                 itl.Remove();
                           }
                           itl.pointer = nextL;
                        }
                        if(!initList.list.first)
                        {
                           it.Remove();
                           delete memberInit;
                        }
                     }
                  }
               }
               if(memberInit)
               {
                  // If we are overriding a whole instance, the mask must still be set!!
                  if(e._class != class(CQL2ExpInstance))
                     memberInit.stylesMask &= ~(memberInit.stylesMask & mask);
               }
            }
         }
         it.pointer = next;
      }
   }

   CQL2MemberInitList copy()
   {
      CQL2MemberInitList c = null;
      if(this)
      {
         c = eInstance_New(_class);
         for(n : this)
            c.Add(n.copy());
      }
      return c;
   }
}

public class CQL2SpecName : CQL2Node
{
   class_no_expansion;

public:
   String name;

   void print(File out, int indent, CQL2OutputOptions o)
   {
      if(name) out.Print(name);
   }

   CQL2SpecName copy()
   {
      CQL2SpecName spec { name = CopyString(name) };
      return spec;
   }

   ~CQL2SpecName()
   {
      delete name;
   }
}

struct OpTable
{
public:
   // binary arithmetic
   bool (* Add)(FieldValue, const FieldValue, const FieldValue);
   bool (* Sub)(FieldValue, const FieldValue, const FieldValue);
   bool (* Mul)(FieldValue, const FieldValue, const FieldValue);
   bool (* Div)(FieldValue, const FieldValue, const FieldValue);
   bool (* DivInt)(FieldValue, const FieldValue, const FieldValue);
   bool (* Mod)(FieldValue, const FieldValue, const FieldValue);

   // unary arithmetic
   bool (* Neg)(FieldValue, const FieldValue);

   // unary arithmetic increment and decrement
   //bool (* Inc)(FieldValue, FieldValue);
   //bool (* Dec)(FieldValue, FieldValue);

   // binary arithmetic assignment
   /*bool (* Asign)(FieldValue, FieldValue, FieldValue);
   bool (* AddAsign)(FieldValue, FieldValue, FieldValue);
   bool (* SubAsign)(FieldValue, FieldValue, FieldValue);
   bool (* MulAsign)(FieldValue, FieldValue, FieldValue);
   bool (* DivAsign)(FieldValue, FieldValue, FieldValue);
   bool (* ModAsign)(FieldValue, FieldValue, FieldValue); */


   // unary logical negation
   bool (* Not)(FieldValue, const FieldValue);

   // binary logical equality
   bool (* Equ)(FieldValue, const FieldValue, const FieldValue);
   bool (* Nqu)(FieldValue, const FieldValue, const FieldValue);

   // binary logical
   bool (* And)(FieldValue, const FieldValue, const FieldValue);
   bool (* Or)(FieldValue, const FieldValue, const FieldValue);

   // binary logical relational
   bool (* Grt)(FieldValue, const FieldValue, const FieldValue);
   bool (* Sma)(FieldValue, const FieldValue, const FieldValue);
   bool (* GrtEqu)(FieldValue, const FieldValue, const FieldValue);
   bool (* SmaEqu)(FieldValue, const FieldValue, const FieldValue);

   // text specific
   bool (* StrCnt)(FieldValue, const FieldValue, const FieldValue);
   bool (* StrSrt)(FieldValue, const FieldValue, const FieldValue);
   bool (* StrEnd)(FieldValue, const FieldValue, const FieldValue);
   bool (* StrNotCnt)(FieldValue, const FieldValue, const FieldValue);
   bool (* StrNotSrt)(FieldValue, const FieldValue, const FieldValue);
   bool (* StrNotEnd)(FieldValue, const FieldValue, const FieldValue);

   // binary bitwise
   bool (* BitAnd)(FieldValue, FieldValue, FieldValue);
   bool (* BitOr)(FieldValue, FieldValue, FieldValue);
   bool (* BitXor)(FieldValue, FieldValue, FieldValue);
   bool (* LShift)(FieldValue, FieldValue, FieldValue);
   bool (* RShift)(FieldValue, FieldValue, FieldValue);
   bool (* BitNot)(FieldValue, FieldValue);

   // binary bitwise assignment
  /* bool (* AndAsign)(FieldValue, FieldValue, FieldValue);
   bool (* OrAsign)(FieldValue, FieldValue, FieldValue);
   bool (* XorAsign)(FieldValue, FieldValue, FieldValue);
   bool (* LShiftAsign)(FieldValue, FieldValue, FieldValue);
   bool (* RShiftAsign)(FieldValue, FieldValue, FieldValue);*/
};


// binary arithmetic
OPERATOR_NUMERIC(BINARY, +, Add) //see textAdd for concat
OPERATOR_NUMERIC(BINARY, -, Sub)
OPERATOR_NUMERIC(BINARY, *, Mul)
OPERATOR_INT(BINARY_DIVIDEINT, /, Div)
OPERATOR_INT(BINARY_DIVIDEINT, /, DivInt)
OPERATOR_REAL(BINARY, /, Div)
OPERATOR_INT(BINARY_DIVIDEINT, %, Mod)

// unary arithmetic
OPERATOR_NUMERIC(UNARY, -, Neg)

// unary arithmetic increment and decrement
//OPERATOR_NUMERIC(UNARY, ++, Inc)   //increment of member 'i' in read-only object
//OPERATOR_NUMERIC(UNARY, --, Dec)


// binary arithmetic assignment
/*OPERATOR_ALL(BINARY, =, Asign)
OPERATOR_NUMERIC(BINARY, +=, AddAsign)
OPERATOR_NUMERIC(BINARY, -=, SubAsign)
OPERATOR_NUMERIC(BINARY, *=, MulAsign)
OPERATOR_INT(BINARY_DIVIDEINT, /=, DivAsign)
OPERATOR_REAL(BINARY_DIVIDEREAL, /=, DivAsign)
OPERATOR_INT(BINARY_DIVIDEINT, %=, ModAsign) */

// binary bitwise
OPERATOR_INT(BINARY, &, BitAnd)
OPERATOR_INT(BINARY, |, BitOr)
OPERATOR_INT(BINARY, ^, BitXor)
OPERATOR_INT(BINARY, <<, LShift)
OPERATOR_INT(BINARY, >>, RShift)

// OPERATOR_REAL(BINARY, &, BitAnd)

static bool realBitAnd(FieldValue value, const FieldValue val1, const FieldValue val2)
{
   value.r = ((uint64)val1.r) & ((uint64)val2.r);
   value.type = { type = integer };
   return true;
}

/*
OPERATOR_REAL(BINARY, |, BitOr)
OPERATOR_REAL(BINARY, ^, BitXor)
OPERATOR_REAL(BINARY, <<, LShift)
OPERATOR_REAL(BINARY, >>, RShift)
*/

// unary bitwise
OPERATOR_INT(UNARY, ~, BitNot)
//OPERATOR_REAL(UNARY, ~, BitNot)


// binary bitwise assignment
/*
OPERATOR_INT(BINARY, &=, AndAsign)
OPERATOR_INT(BINARY, |=, OrAsign)
OPERATOR_INT(BINARY, ^=, XorAsign)
OPERATOR_INT(BINARY, <<=, LShiftAsign)
OPERATOR_INT(BINARY, >>=, RShiftAsign)   */

// unary logical negation
OPERATOR_ALL(UNARY_LOGICAL, !, Not) //OPERATOR_ALL


// binary logical equality
OPERATOR_NUMERIC(BINARY_LOGICAL, ==, Equ)
OPERATOR_NUMERIC(BINARY_LOGICAL, !=, Nqu)

// #define UNICODE_NORMALIZATION_ENABLED

static bool textEqu(FieldValue val, const FieldValue op1, const FieldValue op2)
{
   if(op1.s && op2.s)
   {
#if defined(UNICODE_NORMALIZATION_ENABLED)
      String s1 = normalizeNFD(op1.s), s2 = normalizeNFD(op2.s);
#else
      const String s1 = op1.s, s2 = op2.s;
#endif
      val.i = !strcmp(s1, s2);
#if defined(UNICODE_NORMALIZATION_ENABLED)
      delete s1, delete s2;
#endif
   }
   else if(!op1.s && !op2.s)
      val.i = 1;
   else
      val.i = 0;
   val.type = { type = integer };
   return true;
}

static bool textNqu(FieldValue val, const FieldValue op1, const FieldValue op2)
{
   if(op1.s && op2.s)
   {
#if defined(UNICODE_NORMALIZATION_ENABLED)
      String s1 = normalizeNFD(op1.s), s2 = normalizeNFD(op2.s);
#else
      const String s1 = op1.s, s2 = op2.s;
#endif
      val.i = strcmp(s1, s2);
#if defined(UNICODE_NORMALIZATION_ENABLED)
      delete s1, delete s2;
#endif
   }
   else if(!op1.s && !op2.s)
      val.i = 0;
   else
      val.i = 1;
   val.type = { type = integer };
   return true;
}

// binary logical
OPERATOR_ALL(BINARY_LOGICAL, &&, And)
OPERATOR_ALL(BINARY_LOGICAL, ||, Or)

// binary logical relational
OPERATOR_NUMERIC(BINARY_LOGICAL, >, Grt)
OPERATOR_NUMERIC(BINARY_LOGICAL, <, Sma)
OPERATOR_NUMERIC(BINARY_LOGICAL, >=, GrtEqu)
OPERATOR_NUMERIC(BINARY_LOGICAL, <=, SmaEqu)

// text conditions
static bool textContains(FieldValue result, const FieldValue val1, const FieldValue val2)
{
   if(!(val1.s && val2.s))
      result.i = 0;
   else
   {
#if defined(UNICODE_NORMALIZATION_ENABLED)
      String s1 = normalizeNFD(val1.s), s2 = normalizeNFD(val2.s);
#else
      const String s1 = val1.s, s2 = val2.s;
#endif
      result.i = SearchString(s1, 0, s2, true, false) != null;
#if defined(UNICODE_NORMALIZATION_ENABLED)
      delete s1, delete s2;
#endif
   }
   result.type = { type = integer };
   return true;
}

static bool textStartsWith(FieldValue result, const FieldValue val1, const FieldValue val2)
{
   if(!(val1.s && val2.s))
      result.i = 0;
   else
   {
#if defined(UNICODE_NORMALIZATION_ENABLED)
      String s1 = normalizeNFD(val1.s), s2 = normalizeNFD(val2.s);
#else
      const String s1 = val1.s, s2 = val2.s;
#endif
      int lenStr = strlen(s1), lenSub = strlen(s2);
      result.i = lenSub > lenStr ? 0 : !strncmp(s1, s2, lenSub);
#if defined(UNICODE_NORMALIZATION_ENABLED)
      delete s1, delete s2;
#endif
   }
   result.type = { type = integer };
   return true;
}

static bool textEndsWith(FieldValue result, const FieldValue val1, const FieldValue val2)
{
   if(!(val1.s && val2.s))
      result.i = 0;
   else
   {
#if defined(UNICODE_NORMALIZATION_ENABLED)
      String s1 = normalizeNFD(val1.s), s2 = normalizeNFD(val2.s);
#else
      const String s1 = val1.s, s2 = val2.s;
#endif
      int lenStr = strlen(s1), lenSub = strlen(s2);
      result.i = lenSub > lenStr ? 0 : !strcmp(s1 + (lenStr-lenSub), s2);
#if defined(UNICODE_NORMALIZATION_ENABLED)
      delete s1, delete s2;
#endif
   }
   result.type = { type = integer };
   return true;
}

static bool textDoesntContain(FieldValue result, const FieldValue val1, const FieldValue val2)
{
   textContains(result, val1, val2);
   result.i = !result.i;
   return true;
}

static bool textDoesntStartWith(FieldValue result, const FieldValue val1, const FieldValue val2)
{
   textStartsWith(result, val1, val2);
   result.i = !result.i;
   return true;
}

static bool textDoesntEndWith(FieldValue result, const FieldValue val1, const FieldValue val2)
{
   textEndsWith(result, val1, val2);
   result.i = !result.i;
   return true;
}

static bool textAdd(FieldValue result, const FieldValue val1, const FieldValue val2)
{
   result.type = { type = text, mustFree = true };
   if(!(val1.s && val2.s))
      result.s = null;
   else
   {
#if defined(UNICODE_NORMALIZATION_ENABLED)
      String s1 = normalizeNFD(val1.s), s2 = normalizeNFD(val2.s);
#else
      const String s1 = val1.s, s2 = val2.s;
#endif
      result.s = PrintString(s1, s2);
#if defined(UNICODE_NORMALIZATION_ENABLED)
      delete s1, delete s2;
#endif
   }
   return true;
}

static bool textGrt(FieldValue val, const FieldValue op1, const FieldValue op2)
{
   if(!(op1.s && op2.s))
      val.i = 0;
   else
   {
#if defined(UNICODE_NORMALIZATION_ENABLED)
      String s1 = normalizeNFD(op1.s), s2 = normalizeNFD(op2.s);
#else
      const String s1 = op1.s, s2 = op2.s;
#endif
      val.i = strcmp(s1, s2) > 0;
#if defined(UNICODE_NORMALIZATION_ENABLED)
      delete s1, delete s2;
#endif
   }
   val.type = { type = integer };
   return true;
}

static bool textSma(FieldValue val, const FieldValue op1, const FieldValue op2)
{
   if(!(op1.s && op2.s))
      val.i = 0;
   else
   {
#if defined(UNICODE_NORMALIZATION_ENABLED)
      String s1 = normalizeNFD(op1.s), s2 = normalizeNFD(op2.s);
#else
      const String s1 = op1.s, s2 = op2.s;
#endif
      val.i = strcmp(s1, s2) < 0;
#if defined(UNICODE_NORMALIZATION_ENABLED)
      delete s1, delete s2;
#endif
   }
   val.type = { type = integer };
   return true;
}

static bool textGrtEqu(FieldValue val, const FieldValue op1, const FieldValue op2)
{
   if(!(op1.s && op2.s))
      val.i = 0;
   else
   {
#if defined(UNICODE_NORMALIZATION_ENABLED)
      String s1 = normalizeNFD(op1.s), s2 = normalizeNFD(op2.s);
#else
      const String s1 = op1.s, s2 = op2.s;
#endif
      val.i = strcmp(s1, s2) >= 0;
#if defined(UNICODE_NORMALIZATION_ENABLED)
      delete s1, delete s2;
#endif
   }
   val.type = { type = integer };
   return true;
}

static bool textSmaEqu(FieldValue val, const FieldValue op1, const FieldValue op2)
{
   if(!(op1.s && op2.s))
      val.i = 0;
   else
   {
#if defined(UNICODE_NORMALIZATION_ENABLED)
      String s1 = normalizeNFD(op1.s), s2 = normalizeNFD(op2.s);
#else
      const String s1 = op1.s, s2 = op2.s;
#endif
      val.i = strcmp(s1, s2) <= 0;
#if defined(UNICODE_NORMALIZATION_ENABLED)
      delete s1, delete s2;
#endif
   }
   val.type = { type = integer };
   return true;
}

#include <float.h>

static bool realDivInt(FieldValue val, const FieldValue op1, const FieldValue op2)
{
   val.r = (int)(op1.r / op2.r + FLT_EPSILON);
   val.type = { type = real };
   return true;
}

static bool realMod(FieldValue val, const FieldValue op1, const FieldValue op2)
{
   val.r = fmod(op1.r, op2.r);
   val.type = { type = real };
   return true;
}

public void convertFieldValue(const FieldValue src, FieldTypeEx type, FieldValue dest)
{
   FieldValue origSrc = src;
   if(src.type.type == text)
   {
      if(type.type == real)
      {
         dest.r = strtod(src.s, null);
         dest.type = { real };
      }
      else if(type.type == integer)
      {
         if(type.isDateTime)
         {
            DateTime dt {};
            dt.OnGetDataFromString(src.s);
            dest.i = (SecSince1970)dt;
            dest.type = { integer, isDateTime = true };
         }
         else
         {
            dest.i = strtoll(src.s, null, 0);
            dest.type = { integer };
         }
      }
   }
   else if(src.type.type == integer)
   {
      if(type.isDateTime)
      {
         dest.i = (int64)(SecSince1970)src.i;
         dest.type = { integer };
      }
      else if(type.type == real)
      {
         dest.r = (double)src.i;
         dest.type = { real };
      }
      else if(type.type == text)
      {
         if(src.type.isDateTime)
         {
            DateTime dt = (SecSince1970)src.i;
            dest.s = printTime({ year = true, month = true, day = true, hour = true, minute = true, second = true }, dt);
         }
         else
            dest.s = PrintString(src.i);
         dest.type = { text };
      }
   }
   else if(src.type.type == real)
   {
      if(type.type == integer)
      {
         dest.i = (int64)src.r;
         dest.type = { integer };
      }
      else if(type.type == text)
      {
         dest.s = PrintString(src.r);
         dest.type = { text, mustFree = true };
      }
   }
   else if(src.type.type == nil)
   {
      if(type.type == integer)
      {
         dest.i = 0;
         dest.type = { integer };
      }
      else if(type.type == text)
      {
         dest.s = null;
         dest.type = { text };
      }
   }
   else
      dest = { type = { nil } };
   if(src == dest && origSrc.s != dest.s) // This is sometimes called with the same FieldValue for both src and dest
      origSrc.OnFree();
}

public CQL2Expression expressionFromValue(const FieldValue value, Class c)
{
   CQL2Expression e = null;
   if(c && value.type.type == blob && value.b != null)
   {
      if(eClass_IsDerived(c, class(Container)) && c.templateArgs && c.templateArgs[0].dataTypeString)
      {
         // Arrays / Containers
         Container container = (Container)value.b;
         uint count = container.GetCount();
         CQL2ExpList elements { };
         CQL2ExpArray array { elements = elements, destType = c };
         int i;
         Iterator it { container = container };
         ClassTemplateArgument typeArg = c.templateArgs[0];
         Class type;

         if(!typeArg.dataTypeClass)
             typeArg.dataTypeClass = eSystem_FindClass(__thisModule.application, typeArg.dataTypeString);
         type = typeArg.dataTypeClass;

         if(type)
         {
            FieldTypeEx fType { integer };

            if(type.type == structClass || type.type == noHeadClass || type.type == normalClass)
               fType.type = blob;
            else if(!strcmp(type.dataTypeString, "float") || !strcmp(type.dataTypeString, "double"))
               fType.type = real;
            else if(!strcmp(type.dataTypeString, "char *"))
               fType = { text, mustFree = true };
            else if(type == class(Color))
               fType.format = color; //hex;

            for(i = 0; i < count; i++)
            {
               CQL2Expression ee = null;
               FieldValue v { type = fType };

               it.Next();

               if(fType.type == integer)
               {
                  Iterator<int64> iti { (Container<int64>)container, it.pointer };
                  if(type.typeSize == 4)
                     v.i = (int)iti.GetData();   // FIXME: eC bug causes a warning without these casts?
                  else
                     v.i = (int64)iti.GetData();   // FIXME: eC bug causes a warning without these casts?
               }
               else if(fType.type == real)
               {
                  Iterator<double> iti { (Container<double>)container, it.pointer };
                  v.r = (double)iti.GetData();
               }
               else if(fType.type == text)
               {
                  Iterator<String> its { (Container<String>)container, it.pointer };
                  v.s = CopyString((String)its.GetData());
               }
               else if(fType.type == blob)
               {
                  Iterator<uintptr> itp { (Container<uintptr>)container, it.pointer };
                  v.b = (void *)itp.GetData();
               }

               ee = expressionFromValue(v, type);
               if(ee)
                  elements.Add(ee);
            }
            e = array;
         }
      }
      else
      {
         // TODO: Support for other types of instances?
         if(c.type == structClass)
         {
            DataMember m;
            CQL2Instantiation instance { };
            CQL2ExpInstance ei { instance = instance };

            for(m = c.membersAndProperties.first; m; m = m.next)
            {
               if(!m.isProperty)
               {
                  Class type = m.dataTypeClass;
                  if(!m.dataTypeClass)
                     type = m.dataTypeClass = eSystem_FindClass(c.module, m.dataTypeString);
                  if(type)
                  {
                     FieldValue v { type = { integer } };
                     InstanceMask mask = 0; //evaluator.evaluatorClass.
                     // TOCHECK: Need a mask here too? Would need evaluator class to determine it...

                     if(type.type == structClass || type.type == noHeadClass || type.type == normalClass)
                        v.type.type = blob;
                     else if(!strcmp(type.dataTypeString, "float") || !strcmp(type.dataTypeString, "double"))
                        v.type.type = real;
                     else if(!strcmp(type.dataTypeString, "char *"))
                        v.type = { text, mustFree = true };
                     else if(type == class(Color))
                        v.type.format = color; //hex;

                     if(v.type.type == integer)
                     {
                        if(type.typeSize == 4)
                           v.i = *(int *)((byte *)value.b + m.offset);
                        else
                           v.i = *(int64 *)((byte *)value.b + m.offset);
                     }
                     else if(v.type.type == real)
                     {
                        v.r = *(double *)((byte *)value.b + m.offset);
                     }
                     else if(v.type.type == text)
                     {
                        v.s = CopyString(*(String *)((byte *)value.b + m.offset));
                     }
                     else if(v.type.type == blob)
                     {
                        v.b = (void *)((byte *)value.b + m.offset);
                     }
                     // WARNING: We don't have evaluator and instClass to properly set targetMask here yet...
                     ei.setMemberValue(m.name, mask, true, v, type);
                  }
               }
            }
            e = ei;
         }
      }
   }
   else
   {
      e =
         value.type.type == nil || (value.type.type == blob && value.b == null) ?
            CQL2ExpIdentifier { identifier = { string = CopyString("null") } } :
         value.type.type == text ? CQL2ExpString { string = CopyString(value.s) } :
         CQL2ExpConstant { destType = c, constant = value };
      if(c && c.type == unitClass && c.base && c.base.type == unitClass && e._class == class(CQL2ExpConstant))
      {
         String s = CopyString(c.name);
         CQL2MemberInit minit { initializer = e };
         CQL2MemberInitList memberInitList { [ minit ] };
         CQL2Instantiation instantiation
         {
            _class = CQL2SpecName { name = CopyString(s) }, // e.g. "Meters"
            members = { [ memberInitList ] }
         };
         e.destType = null;
         e = CQL2ExpInstance { destType = c, instance = instantiation };
      }
   }
   return e;
}
