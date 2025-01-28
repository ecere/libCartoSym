public import IMPORT_STATIC "ecere"
public import IMPORT_STATIC "EDA" // For FieldValue

public import "stringTools"
public import "iso8601"
public import "lexing"
public import "astNode"
public import "cartoSym"

default:
extern int __ecereVMethodID_class_OnGetDataFromString;
extern int __ecereVMethodID_class_OnGetString;
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

static CartoSymTokenType opPrec[][8] =
{
   { '*', '/', intDivide, '%' },
   { '+', '-' },
   { in },
   { lShift, rShift },
   { '<', '>', smallerEqual, greaterEqual },
   { equal, notEqual, stringStartsWith, stringNotStartsW, stringEndsWith, stringNotEndsW, stringContains, stringNotContains },
   { bitAnd },
   { bitOr },
   { bitNot },
   { bitXor },
   { and },
   { or }
};

static define numPrec = sizeof(opPrec) / sizeof(opPrec[0]);

public bool isLowerEqualPrecedence(CartoSymTokenType opA, CartoSymTokenType opB)
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

static bool isPrecedence(CartoSymTokenType this, int l)
{
   if(this)
   {
      int o;
      for(o = 0; o < sizeof(opPrec[0]) / sizeof(opPrec[0][0]); o++)
      {
         CartoSymTokenType op = opPrec[l][o];
         if(this == op)
            return true;
         else if(!op)
            break;
      }
   }
   return false;
}

OpTable opTables[FieldType] =
{
   OPERATOR_TABLE_EMPTY(nil),
   OPERATOR_TABLE_INT(integer),
   OPERATOR_TABLE_REAL(real),
   OPERATOR_TABLE_TEXT(text)
};

public class ExpFlags : uint
{
public:
   bool resolved:1:0;
   bool invalid:1:5;
   bool isNotLiteral:1:7; // REVIEW: Do we really need this flag
};

public enum ComputeType { preprocessing, runtime, other };

void * copyList(List list, CartoSymNode copy(CartoSymNode))
{
   List<CartoSymNode> result = null;
   if(list)
   {
      result = eInstance_New(list._class);
      for(l : list)
         result.Add(copy((CartoSymNode)l));
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

public CartoSymExpression simplifyResolved(FieldValue val, CartoSymExpression e)
{
   // Handling some conversions here...
   Class destType = e.destType;
   if(destType && e.expType != destType)
   {
      if(destType == class(float) || destType == class(double))
         convertFieldValue(val, {real}, val);
      else if(destType == class(String))
         convertFieldValue(val, {text}, val);
      else if(destType == class(int64) || destType == class(int) || destType == class(uint64) || destType == class(uint))
         convertFieldValue(val, {integer}, val);
   }

   if(e._class == class(CartoSymExpBrackets) && ((CartoSymExpBrackets)e).list && ((CartoSymExpBrackets)e).list.list.count > 1)
      return e; // Do not simplify lists with more than one element
   else if(e._class == class(CartoSymExpConditional))
   {
      CartoSymExpConditional conditional = (CartoSymExpConditional)e;
      CartoSymExpression ne = null;
      if(conditional.result)
      {
         CartoSymExpression last = conditional.expList ? conditional.expList.lastIterator.data : null;
         if(last)
            ne = last, conditional.expList.TakeOut(last);
      }
      else
         ne = conditional.elseExp, conditional.elseExp = null;
      ne = simplifyResolved(val, ne);
      delete e;
      return ne;
   }
   else if(e._class != class(CartoSymExpString) && e._class != class(CartoSymExpConstant) && e._class != class(CartoSymExpInstance) && e._class != class(CartoSymExpArray))
   {
      CartoSymExpression ne = (val.type.type == text) ? (val.s ? CartoSymExpString { string = CopyString(val.s) } :  CartoSymExpIdentifier { identifier = CartoSymIdentifier { string = CopyString("null") } })  : CartoSymExpConstant { constant = val };
      ne.destType = e.destType;
      ne.expType = e.expType;
      delete e;
      return ne;
   }
   else if(e._class == class(CartoSymExpInstance))
   {
      Class c = e.expType ? e.expType : e.destType;   // NOTE: At this point, expType should be set but is currently null?
      if(c && c.type == bitClass)
      {
         CartoSymExpression ne = CartoSymExpConstant { constant = val };
         ne.destType = e.destType;
         ne.expType = e.expType;
         delete e;
         return ne;
      }
      else if(c && c == class(DateTime) && val.type.isDateTime)
      {
         CartoSymExpression ne = CartoSymExpConstant { constant = val };
         ne.destType = e.destType;
         ne.expType = e.expType;
         delete e;
         return ne;
      }
   }
   return e;
}

public CartoSymExpression parseCartoSymExpression(const String string)
{
   CartoSymExpression e = null;
   if(string)
   {
      CartoSymLexer lexer { };
      lexer.initString(string);
      e = CartoSymExpression::parse(lexer);

      if(lexer.type == lexingError || (lexer.nextToken && lexer.nextToken.type != endOfInput))
      {
#ifdef _DEBUG
         if(lexer.type == lexingError)
            PrintLn("ECCSS Lexing Error at line ", lexer.pos.line, ", column ", lexer.pos.col);
         else
            PrintLn("ECCSS Syntax Error: Unexpected token ", lexer.nextToken.type,
               lexer.nextToken.text ? lexer.nextToken.text : "",
               " at line ", lexer.pos.line, ", column ", lexer.pos.col);
#endif
         delete e;
      }

      delete lexer;
   }
   return e;
}


public class CartoSymIdentifier : CartoSymNode
{
public:
   String string;

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      bool quote = !string || needsQuotes(string);
      if(quote) out.Print('`');
      out.Print(string ? string : "<null>");
      if(quote) out.Print('`');
   }

   bool ::needsQuotes(const String string)
   {
      bool quote = isdigit(string[0]) || strchr(string, ' ') || strchr(string, ':');
      return quote;
   }

   CartoSymIdentifier ::parse(CartoSymLexer lexer)
   {
      lexer.readToken();
      return { string = CopyString(lexer.token.text) };
   }

   CartoSymIdentifier copy()
   {
      CartoSymIdentifier id { string = CopyString(string) };
      return id;
   }

   ~CartoSymIdentifier()
   {
      delete string;
   }
};

// Expressions
public class CartoSymExpression : CartoSymNode
{
public:
   DataValue val;
   Class destType;
   Class expType;

   //virtual float compute();
   public virtual ExpFlags compute(FieldValue value, ECCSSEvaluator evaluator, ComputeType computeType, Class stylesClass);

   CartoSymExpression ::parse(CartoSymLexer lexer)
   {
      CartoSymExpression e = CartoSymExpConditional::parse(lexer);
      if(lexer.type == lexingError ||
         lexer.type == syntaxError ||
         (lexer.nextToken && (lexer.nextToken.type == lexingError || lexer.nextToken.type == syntaxError)))
         delete e;
      return e;
   }
}

public class CartoSymExpList : CartoSymList<CartoSymExpression>
{
public:
   CartoSymExpList ::parse(CartoSymLexer lexer)
   {
      return (CartoSymExpList)CartoSymList::parse(class(CartoSymExpList), lexer, CartoSymExpression::parse, ',');
   }

   CartoSymExpList copy()
   {
      CartoSymExpList e { };
      for(n : list)
         e.list.Add(n.copy());
      return e;
   }
}

static CartoSymExpression parseSimplePrimaryExpression(CartoSymLexer lexer)
{
   if(lexer.peekToken().type == constant)
      return CartoSymExpConstant::parse(lexer);
   else if(lexer.nextToken.type == identifier)
   {
      CartoSymExpIdentifier exp = CartoSymExpIdentifier::parse(lexer);
      if(lexer.peekToken().type == '{')
      {
         CartoSymSpecName spec { name = CopyString(exp.identifier.string) };
         delete exp;
         return CartoSymExpInstance::parse(spec, lexer);
      }
      return exp;
   }
   else if(lexer.nextToken.type == stringLiteral)
      return CartoSymExpString::parse(lexer);
   else if(lexer.nextToken.type == '{')
      return CartoSymExpInstance::parse(null, lexer);
   else if(lexer.nextToken.type == '[')
      return CartoSymExpArray::parse(lexer);
   else
   {
      // This could happen e.g., at the end of a list with next token being ']'
      return null;
   }
}

static CartoSymExpression parsePrimaryExpression(CartoSymLexer lexer)
{
   if(lexer.peekToken().type == '(')
   {
      CartoSymExpBrackets exp { };
      lexer.readToken();
      exp.list = CartoSymExpList::parse(lexer);
      if(lexer.peekToken().type == ')')
         lexer.readToken();
      return exp;
   }
   else
      return parseSimplePrimaryExpression(lexer);
}

static CartoSymExpression parsePostfixExpression(CartoSymLexer lexer)
{
   CartoSymExpression exp = parsePrimaryExpression(lexer);
   while(exp) //true)
   {
      if(lexer.peekToken().type == '[')
         exp = CartoSymExpIndex::parse(exp, lexer);
      else if(lexer.nextToken.type == '(')
         exp = CartoSymExpCall::parse(exp, lexer);
      else if(lexer.nextToken.type == '.')
         exp = CartoSymExpMember::parse(exp, lexer);
      else
         break;
   }
   return exp;
}

static CartoSymExpression parseUnaryExpression(CartoSymLexer lexer)
{
   lexer.peekToken();
   if(lexer.nextToken.type.isUnaryOperator)
   {
      CartoSymTokenType tokenType;
      CartoSymExpression exp2;

      lexer.readToken();
      tokenType = lexer.token.type;
      exp2 = parseUnaryExpression(lexer);
      if(tokenType == minus && exp2 && exp2._class == class(CartoSymExpConstant))
      {
         CartoSymExpConstant c = (CartoSymExpConstant)exp2;
         if(c.constant.type.type == integer)
            c.constant.i *= -1;
         else
            c.constant.r *= -1;
         return c;
      }
      else
         return CartoSymExpOperation { op = tokenType, exp2 = exp2 };
   }
   else
      return parsePostfixExpression(lexer);
}

public class CartoSymExpConstant : CartoSymExpression
{
public:
   FieldValue constant;

   void print(File out, int indent, CartoSymOutputOptions o)
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
         const char *(* onGetString)(void *, void *, char *, void *, ObjectNotationType *) = type._vTbl[__ecereVMethodID_class_OnGetString];
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
               (__runtimePlatform == win32) ? "0x%06I64X" : "0x%06llX",
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
      else out.Print(constant);
   }

   CartoSymExpConstant ::parse(CartoSymLexer lexer)
   {
      CartoSymExpConstant result = null;
      CartoSymToken token = lexer.readToken();
      // check token, if starts with quote or contains comma... parse to know type, integer string etc,... set i s or r
      // no text here, use CartoSymexpstring

      if(isdigit(token.text[0]))
      {
         int multiplier = 1;
         int len = strlen(token.text);

         if(token.text[len-1] == 'K') multiplier = 1000;
         else if(token.text[len-1] == 'M') multiplier = 1000000;

         if(strchr(token.text, '.') ||
            ((token.text[0] != '0' || token.text[1] != 'x') && (strchr(token.text, 'E') || strchr(token.text, 'e'))))
         {
            result = { constant = { r = strtod(token.text, null) * multiplier, type.type = real } };
            if(strchr(token.text, 'E') || strchr(token.text, 'e'))
               result.constant.type.format = exponential;
         }
         else
         {
            result = { constant = { i = strtoll(token.text, null, 0) * multiplier, type.type = integer} };
            if(strstr(token.text, "0x"))
               result.constant.type.format = hex;
            else if(strstr(token.text, "b"))
               result.constant.type.format = binary;
            else if(token.text[0] == '0' && isdigit(token.text[1]))
               result.constant.type.format = octal;
         }
      }
      return result;
   }

   CartoSymExpConstant copy()
   {
      CartoSymExpConstant e { constant = constant, expType = expType, destType = destType };
      if(e.constant.type.type == text && e.constant.type.mustFree)
         e.constant.s = CopyString(e.constant.s);
      return e;
   }

   ExpFlags compute(FieldValue value, ECCSSEvaluator evaluator, ComputeType computeType, Class stylesClass)
   {
      value = constant;
      switch(value.type.type)
      {
         case real: expType = class(double); break;
         case integer: expType = class(int64); break;
      }
      return ExpFlags { resolved = true };
   }

   ~CartoSymExpConstant()
   {
      if(constant.type.mustFree == true && constant.type.type == text )
         delete constant.s;
   }
}

public class CartoSymExpString : CartoSymExpression
{
public:
   String string;

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      int len = strlen(string) * 2 + 1;
      String buf = new char[len];
      EscapeCString(buf, len, string, { escapeSingleQuote = true });
      out.Print('\'', buf, '\'');
      delete buf;
   }

   CartoSymExpString ::parse(CartoSymLexer lexer)
   {
      int len;
      String s;
      lexer.readToken();
      len = strlen(lexer.token.text)-2;  // len source string length for UnescapeCString()
      s = new char[len+1];
      len = UnescapeCString(s, lexer.token.text+1, len);
      s = renew s char[len+1];
      // memcpy(s, lexer.token.text+1, len);
      // s[len] = 0;
      return { string = s };
   }
   ExpFlags compute(FieldValue value, ECCSSEvaluator evaluator, ComputeType computeType, Class stylesClass)
   {
      value.s = string;
      value.type = { type = text };
      expType = class(String);
      return ExpFlags { resolved = true };
   }

   CartoSymExpString copy()
   {
      CartoSymExpString e { string = CopyString(string), expType = expType, destType = destType };
      return e;
   }

   ~CartoSymExpString()
   {
      delete string;
   }
}

public class CartoSymExpIdentifier : CartoSymExpression
{
public:
   CartoSymIdentifier identifier;
   int fieldID;

   CartoSymExpIdentifier copy()
   {
      CartoSymExpIdentifier e
      {
         identifier = identifier.copy(),
         fieldID = fieldID, // TOCHECK: Should we copy fieldID here ?
         expType = expType, destType = destType
      };
      return e;
   }

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      identifier.print(out, indent, o);
   }

   CartoSymExpIdentifier ::parse(CartoSymLexer lexer)
   {
      return { identifier = CartoSymIdentifier::parse(lexer) };
   }

   ExpFlags compute(FieldValue value, ECCSSEvaluator evaluator, ComputeType computeType, Class stylesClass)
   {
      //Class c = destType ? destType : class(FieldValue); //filler
      //bool *(* onGetDataFromString)(Class, void *, const char *) = destType._vTbl[__ecereVMethodID_class_OnGetDataFromString];
      ExpFlags flags { };
      //bool (* onGetDataFromString)(void *, void *, const char *) = (void *)destType._vTbl[__ecereVMethodID_class_OnGetDataFromString];
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
            bool (* onGetDataFromString)(void *, void *, const char *) = (void *)destType._vTbl[__ecereVMethodID_class_OnGetDataFromString];

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

   CartoSymExpIdentifier()
   {
      fieldID = -1;
   }

   ~CartoSymExpIdentifier()
   {
      delete identifier;
   }
}

public class CartoSymExpOperation : CartoSymExpression
{
public:
   CartoSymTokenType op;
   CartoSymExpression exp1, exp2;
   bool falseNullComparisons;

   CartoSymExpOperation copy()
   {
      CartoSymExpOperation e
      {
         op = op,
         exp1 = exp1 ? exp1.copy() : null,
         exp2 = exp2 ? exp2.copy() : null,
         expType = expType, destType = destType,
         falseNullComparisons = falseNullComparisons
      };
      return e;
   }

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      if(exp1)
      {
         if(exp1._class == (void *)(uintptr)0xecececececececec)
            out.Print("<freed exp>");
         else
            exp1.print(out, indent, o);
         if(exp2) out.Print(" ");
      }
      op.print(out, indent, o);
      if(exp2)
      {
         if(exp1 || op == bitNot) out.Print(" ");

         if(exp2._class == (void *)(uintptr)0xecececececececec)
            out.Print("<freed exp>");
         else
            exp2.print(out, indent, o);
      }
   }

   CartoSymExpression ::parse(int prec, CartoSymLexer lexer)
   {
      CartoSymExpression exp = (prec > 0) ? parse(prec-1, lexer) : parseUnaryExpression(lexer);
      while(isPrecedence(lexer.peekToken().type, prec))
      {
         CartoSymTokenType op = lexer.readToken().type;
         if(exp || op.isUnaryOperator)
         {
            exp = CartoSymExpOperation { exp1 = exp, op = op, exp2 = (prec > 0) ? parse(prec-1, lexer) : parseUnaryExpression(lexer) };
         }
         else
            // Syntax error: binary operator with only right operand
            delete exp;
      }
      return exp;
   }

   ExpFlags compute(FieldValue value, ECCSSEvaluator evaluator, ComputeType computeType, Class stylesClass) //float
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

         flags1 = exp1.compute(val1, evaluator, computeType, stylesClass);
         if(!(flags1.resolved && op == and && val1.type.type == integer && !val1.i)) // Lazy AND evaluation
            flags2 = exp2.compute(val2, evaluator,
               computeType == runtime && !flags1.resolved && op == and ? preprocessing : computeType, stylesClass);
         flags = flags1 | flags2;

         if(op == in)
         {
            CartoSymList<CartoSymExpression> l = (CartoSymList<CartoSymExpression>)exp2;
            if(l && l._class == class(CartoSymExpBrackets))
            {
               l = ((CartoSymExpBrackets)l).list;
            }
            else if(l && l._class == class(CartoSymExpArray))
            {
               l = ((CartoSymExpArray)l).elements;
            }
            if(l && eClass_IsDerived(l._class, class(CartoSymList<CartoSymExpression>)))
            {
               FieldValue v { type = { type = nil } };
               FieldValue v1 { };

               v1.OnCopy(val1);

               for(e : l.list)
               {
                  CartoSymExpression ne = e;
                  FieldValue v2 { type = { type = nil } };
                  ExpFlags f2 = ne.compute(v2, evaluator, computeType, stylesClass);
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
         ExpFlags flags2 = exp2.compute(val2, evaluator, computeType, stylesClass);
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

   ~CartoSymExpOperation()
   {
      delete exp1;
      delete exp2;
   }
}

public class CartoSymExpBrackets : CartoSymExpression
{
public:
   CartoSymExpList list;

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      out.Print("(");
      if(list) list.print(out, indent, o);
      out.Print(")");
   }

   CartoSymExpBrackets copy()
   {
      return CartoSymExpBrackets { list = list.copy(), expType = expType, destType = destType };
   }

   ExpFlags compute(FieldValue value, ECCSSEvaluator evaluator, ComputeType computeType, Class stylesClass)
   {
      ExpFlags flags = 0;
      if(list)
      {
         Iterator<CartoSymExpression> last { container = list, pointer = list.GetLast() };
         CartoSymExpression lastExp = last.data;
         if(lastExp)
         {
            lastExp.destType = destType;
            flags = lastExp.compute(value, evaluator, computeType, stylesClass);
            expType = lastExp.expType;
         }
      }
      return flags;
   }

   ~CartoSymExpBrackets()
   {
      delete list;
   }
}

public class CartoSymExpConditional : CartoSymExpression
{
public:
   CartoSymExpression condition;
   CartoSymExpList expList;
   CartoSymExpression elseExp;
   bool result; // Work-around for simplifyResolved() challenges not having access to computed condition FieldValue

   CartoSymExpConditional copy()
   {
      CartoSymExpConditional e
      {
         condition = condition ? condition.copy() : null,
         expList = expList ? expList.copy() : null,
         elseExp = elseExp ? elseExp.copy() : null,
         expType = expType, destType = destType
      };
      return e;
   }

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      if(condition) condition.print(out, indent, o);
      out.Print(" ? ");
      if(expList) expList.print(out, indent, o);
      out.Print(" : ");
      if(elseExp)
         elseExp.print(out, indent, o);
   }

   CartoSymExpression ::parse(CartoSymLexer lexer)
   {
      CartoSymExpression exp = CartoSymExpOperation::parse(numPrec-1, lexer);
      if(lexer.peekToken().type == '?')
      {
         lexer.readToken();
         exp = CartoSymExpConditional { condition = exp, expList = CartoSymExpList::parse(lexer) };
         if(lexer.peekToken().type == ':')
         {
            lexer.readToken();
            ((CartoSymExpConditional)exp).elseExp = CartoSymExpConditional::parse(lexer);
            if(!((CartoSymExpConditional)exp).elseExp)
               delete exp;
         }
         else
         {
#ifdef _DEBUG
            PrintLn("ECCSS Syntax Error: Conditional expression missing else condition ",
               " at line ", lexer.pos.line, ", column ", lexer.pos.col);
#endif
            delete exp; // Syntax error
         }
      }
      return exp;
   }

   ExpFlags compute(FieldValue value, ECCSSEvaluator evaluator, ComputeType computeType, Class stylesClass)
   {
      // RVVIEW: computeType ignored here ?
      ExpFlags flags = 0;
      FieldValue condValue { };
      ExpFlags flagsCond = condition.compute(condValue, evaluator, computeType, stylesClass);
      if(flagsCond.resolved)
      {
         result = (bool)condValue.i;
         if(condValue.i)
         {
            CartoSymExpression last = expList.lastIterator.data;   // CartoSym Only currently supports a single expression...
            if(last)
            {
               last.destType = destType;
               flags = last.compute(value, evaluator, computeType, stylesClass);
               if(!expType) expType = last.expType;
            }
         }
         else
         {
            flags = elseExp.compute(value, evaluator, computeType, stylesClass);
            if(elseExp && !expType) expType = elseExp.expType;
         }
         if(!flags.resolved && computeType == preprocessing)   // REVIEW: Do we avoid simplifyResolved() at runtime so as to not modify expressions?
            condition = simplifyResolved(condValue, condition);
          // TODO: Support for replacing condition expression entirely eventually?
      }
      else
      {
         CartoSymExpression last = expList.lastIterator.data;   // CartoSym Only currently supports a single expression...
         FieldValue val1 { };
         FieldValue val2 { };
         ExpFlags flags1;
         ExpFlags flags2;
         if(last) last.destType = destType;
         if(elseExp) elseExp.destType = destType;
         flags1 = last ? last.compute(val1, evaluator, computeType, stylesClass) : 0;
         flags2 = elseExp ? elseExp.compute(val2, evaluator, computeType, stylesClass) : 0;

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

   ~CartoSymExpConditional()
   {
      delete condition;
      delete expList;
      delete elseExp;
   }
}

public class CartoSymExpIndex : CartoSymExpression
{
public:
   CartoSymExpression exp;
   CartoSymExpList index;

   CartoSymExpIndex copy()
   {
      CartoSymExpIndex e { exp = exp.copy(), index = index.copy(), expType = expType, destType = destType };
      return e;
   }

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      if(exp) exp.print(out, indent, o);
      out.Print("[");
      if(index) index.print(out, indent, o);
      out.Print("]");
   }

   CartoSymExpIndex ::parse(CartoSymExpression e, CartoSymLexer lexer)
   {
      CartoSymExpIndex exp;
      lexer.readToken();
      exp = CartoSymExpIndex { exp = e, index = CartoSymExpList::parse(lexer) };
      if(lexer.peekToken().type == ']')
         lexer.readToken();
      return exp;
   }
   ExpFlags compute(FieldValue value, ECCSSEvaluator evaluator, ComputeType computeType, Class stylesClass)
   {
      ExpFlags flags { };
      //value = exp.compute;
      return flags;
   }

   ~CartoSymExpIndex()
   {
      delete exp;
      delete index;
   }
}

public class CartoSymExpMember : CartoSymExpression
{
public:
   CartoSymExpression exp;
   CartoSymIdentifier member;

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      if(exp) exp.print(out, indent, o);
      out.Print(".");
      if(member)
         member.print(out, indent, o);
   }

   CartoSymExpMember copy()
   {
      CartoSymExpMember e { exp = exp.copy(), member = member.copy(), expType = expType, destType = destType };
      return e;
   }

   CartoSymExpMember ::parse(CartoSymExpression e, CartoSymLexer lexer)
   {
      lexer.readToken();
      return { exp = e, member = CartoSymIdentifier::parse(lexer) };
   }
   ExpFlags compute(FieldValue value, ECCSSEvaluator evaluator, ComputeType computeType, Class stylesClass)
   {
      ExpFlags flags { };
      FieldValue val { };
      ExpFlags expFlg = exp.compute(val, evaluator, computeType, stylesClass);
      // REVIEW: Can we check for runtime here?
      // REVIEW: If the expression is really resolved during preprocessing, it might be possible to compute it already,
      //         but some scenarios might not yet be handled properly
      if(expFlg.resolved && evaluator != null && computeType == runtime && exp.expType)
      {
         // FIXME: Can we compute this prop and save it in class to compute it only during preprocessing?
         DataMember prop = eClass_FindDataMember(exp.expType, member.string, exp.expType.module, null, null);
         if(!prop)
         {
            prop = (DataMember)eClass_FindProperty(exp.expType, member.string, exp.expType.module);
         }
         // This is not right, the type of the member is different...: expType = exp.expType;
         if(prop)
            evaluator.evaluatorClass.evaluateMember(evaluator, prop, exp, val, value, &flags);
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

   ~CartoSymExpMember()
   {
      delete exp;
      delete member;
   }
}

public class CartoSymExpCall : CartoSymExpression
{
public:
   CartoSymExpression exp;
   CartoSymExpList arguments;

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      if(exp) exp.print(out, indent, o);
      out.Print("(");
      if(arguments) arguments.print(out, indent, o);
      out.Print(")");
   }

   CartoSymExpCall copy()
   {
      CartoSymExpCall e { exp = exp.copy(), arguments = arguments.copy(), expType = expType, destType = destType };
      return e;
   }

   CartoSymExpCall ::parse(CartoSymExpression e, CartoSymLexer lexer)
   {
      CartoSymExpCall exp;
      lexer.readToken();
      exp = CartoSymExpCall { exp = e, arguments = CartoSymExpList::parse(lexer) };
      if(lexer.peekToken().type == ')')
         lexer.readToken();
      return exp;
   }

   ExpFlags compute(FieldValue value, ECCSSEvaluator evaluator, ComputeType computeType, Class stylesClass)
   {
      ExpFlags flags { };

      value.type.type = nil;
      if(exp)
      {
         FieldValue expValue { type = { nil } };
         FieldValue args[50]; // Max 50 args for now?
         int i, numArgs = 0;
         subclass(ECCSSEvaluator) evaluatorClass = evaluator.evaluatorClass;

         if(computeType == preprocessing)
            exp.destType = class(GlobalFunction);

         flags |= exp.compute(expValue, evaluator, computeType, stylesClass);
         if(arguments)
         {
            bool nonResolved = false;
            Link<CartoSymExpression> a;

            flags.resolved = false;
            if(computeType == preprocessing)
               expType = evaluatorClass.resolveFunction(evaluator, expValue, arguments, &flags, destType);
                                                                     // WARNING: This may not be enough for interpolate() / map()
            for(a = (Link<CartoSymExpression>)arguments.list.first; a && numArgs < 50; a = a.next)
            {
               CartoSymExpression arg = (CartoSymExpression)(uintptr)*&a.data;
               FieldValue * argV = &args[numArgs++];
               flags.resolved = false;

               *argV = { }; // FIXME: compute() sometimes returns uninitialized value
               flags |= arg.compute(argV, evaluator, computeType, stylesClass);

               // NOTE: for interpolation handling use color format, ECCSSEvaluator_computeFunction does not have access to destType
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

   ~CartoSymExpCall()
   {
      delete exp;
      delete arguments;
   }
}

public class CartoSymExpArray : CartoSymExpression
{
public:
   CartoSymList<CartoSymExpression> elements;
   Array array;

   CartoSymExpArray copy()
   {
      CartoSymExpArray e { elements = elements.copy(), expType = expType, destType = destType };
      return e;
   }

   CartoSymExpArray ::parse(CartoSymLexer lexer)
   {
      CartoSymExpArray exp { };
      lexer.readToken();
      exp.elements = (CartoSymList<CartoSymExpression>)CartoSymList::parse(class(CartoSymList<CartoSymExpression>), lexer, CartoSymExpression::parse, ',');
      if(lexer.peekToken().type == ']')
         lexer.readToken();
      return exp;
   }

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      Class type = expType ? expType : destType;
      ClassTemplateArgument * a = type ? &type.templateArgs[0] : null;
      Class et = a ? a->dataTypeClass : null;
      int count = elements ? elements.GetCount() : 0;

      if(!count || !et || (et.type != structClass && et.type != normalClass))
      {
         out.Print("[ ");
         if(elements) elements.print(out, indent, o);
         out.Print(" ]");
      }
      else
      {
         int i = 0;

         out.PrintLn("[");
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
         out.Print("]");
      }
   }

   ExpFlags compute(FieldValue value, ECCSSEvaluator evaluator, ComputeType computeType, Class stylesClass)
   {
      ExpFlags flags { };
      bool resolved = true;
      Class type = expType ? expType : destType;
      int i = 0;

      // TOCHECK: any issue to set resolved to true if all elements are resolved?
      delete array;

      if(!type && elements)
      {
         CartoSymExpression e0 = elements[0];
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
         CartoSymExpression exp = e;
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
               if(v.type.type == real)
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
            value = { type = { blob }, b = array };
         flags.resolved = resolved;
      }
      else
         // REVIEW: Shouldn't resolved sometimes be set in preprocessing, if all elements are resolved?
         // if(!resolved) flags.resolved = false;
         flags.resolved = false;
      return flags;
   }

   ~CartoSymExpArray()
   {
      delete elements;
      delete array;
   }
}

extern int __ecereVMethodID_class_OnCopy;
extern int __ecereVMethodID_class_OnFree;

public class CartoSymExpInstance : CartoSymExpression
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
   CartoSymInstantiation instance;
   StylesMask targetMask;
   void * instData;
   ExpFlags instanceFlags;

   CartoSymExpInstance ::parse(CartoSymSpecName spec, CartoSymLexer lexer)
   {
      return { instance = CartoSymInstantiation::parse(spec, lexer) };
   }

   CartoSymExpInstance copy()
   {
      CartoSymExpInstance e
      {
         instance = instance ? instance.copy() : null,
         targetMask = targetMask, expType = expType, destType = destType
      };
      if(instData && instanceFlags == { resolved = true } && expType)
      {
         // Avoid re-computation of resolved instance
         void (* onCopy)(void *, void *, void *) = expType._vTbl[__ecereVMethodID_class_OnCopy];
         if(expType.type == structClass)
         {
            e.instData = new0 byte[expType.structSize];
            onCopy(expType, e.instData, instData);
            e.instanceFlags = instanceFlags;
         }
      }
      return e;
   }

   void print(File out, int indent, CartoSymOutputOptions o)
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

   ExpFlags compute(FieldValue value, ECCSSEvaluator evaluator, ComputeType computeType, Class stylesClass)
   {
      ExpFlags flags = 0; //can an instance be resolved entirely to a constant? -- we resolve it to a 'blob' FieldValue

      if(computeType == preprocessing && (!instData || instanceFlags != { resolved = true }))
      {
         Class c = evaluator.evaluatorClass.getClassFromInst(instance, destType, &stylesClass);
         int memberID = 0;

         if(instance)
         {
            for(inst : instance.members)
            {
               CartoSymMemberInitList member = inst;
               for(m : member)
               {
                  CartoSymMemberInit mInit = m;
                  flags |= mInit.precompute(stylesClass, c, targetMask, &memberID, evaluator);
               }
            }
         }
         if(flags.resolved && c && c.type == bitClass)
         {
            value.type = { integer };
            value.i = 0;
            setGenericBitMembers(this, (uint64 *)&value.i, evaluator, &flags, stylesClass);
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
               const void (* onFree)(void *, void *) = expType._vTbl[__ecereVMethodID_class_OnFree];
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
               CartoSymMemberInitList members = i;
               for(m : members)
               {
                  CartoSymMemberInit mInit = m;
                  if(mInit.initializer)
                  {
                     CartoSymExpression exp = mInit.initializer;
                     if(destType == class(Color))
                     {
                        FieldValue val {};
                        String s = (mInit.identifiers && mInit.identifiers.first) ? mInit.identifiers[0].string : null;
                        Color col = (Color)value.i;
                        flags |= exp.compute(val, evaluator, runtime, stylesClass);
                        if(!strcmp(s, "r"))
                           col.r = (byte)Min(Max(val.i,0),255);
                        else if(!strcmp(s, "g"))
                           col.g = (byte)Min(Max(val.i,0),255);
                        else if(!strcmp(s, "b"))
                           col.b = (byte)Min(Max(val.i,0),255);
                        value.i = col;
                     }
                     else
                        flags |= exp.compute(value, evaluator, runtime, stylesClass);
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

   void setMemberValue(const String idsString, StylesMask mask, bool createSubInstance, const FieldValue value, Class c)
   {
      setMember2(idsString, mask, createSubInstance, expressionFromValue(value, c), null, null, none);
   }

   void setMemberValue2(const String idsString, StylesMask mask, bool createSubInstance, const FieldValue value, Class c, ECCSSEvaluator evaluator, Class stylesClass)
   {
      setMember2(idsString, mask, createSubInstance, expressionFromValue(value, c), evaluator, stylesClass, none);
   }

   void setMember(const String idsString, StylesMask mask, bool createSubInstance, CartoSymExpression expression)
   {
      setMember2(idsString, mask, createSubInstance, expression, null, null, none);
   }

   void setMember2(const String idsString, StylesMask mask, bool createSubInstance, CartoSymExpression expression, ECCSSEvaluator evaluator, Class stylesClass, CartoSymTokenType tt)
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
            Iterator<CartoSymMemberInitList> it { (void *)instance.members.list };

            it.Prev();
            while(it.pointer)
            {
               IteratorPointer prev = it.container.GetPrev(it.pointer);
               CartoSymMemberInitList im = it.data;
               if(im)
               {
                  if(!placed && im.setSubMember(createSubInstance, expType, idsString, mask, expression, null, evaluator, stylesClass, none))
                     placed = true;
                  else
                  {
                     IteratorPointer after = null;

                     if(im.removeByIDs(idsString, mask, &after) && !placed)
                     {
                        CartoSymMemberInit mInit;
                        CartoSymMemberInitList::setSubMember(null, createSubInstance, expType, idsString, mask, expression, &mInit, evaluator, stylesClass, none);
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
            CartoSymMemberInitList initList = strchr(idsString, '.') ? null : instance.members.lastIterator.data;
            if(!initList)
               instance.members.Add((initList = { }));
            initList.setMember2(expType, idsString, mask, createSubInstance, expression, evaluator, stylesClass, tt);
            instance.members.mask |= mask;
         }
      }
   }

   public CartoSymExpression getMemberByIDs(Container<const String> ids)
   {
      CartoSymExpression result = null;
      if(this && this._class == class(CartoSymExpInstance))
      {
         CartoSymExpInstance ei = (CartoSymExpInstance)this;
         if(ei.instance && ei.instance.members)
         {
            for(m : ei.instance.members)
            {
               CartoSymMemberInitList members = m;
               if(members)
               {
                  CartoSymExpression r = members.getMemberByIDs(ids);
                  if(r)
                     result = r;
               }
            }
         }
      }
      return result;
   }

   ~CartoSymExpInstance()
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
            const void (* onFree)(void *, void *) = expType._vTbl[__ecereVMethodID_class_OnFree];
            onFree(expType, instData);
            delete instData;
         }
         else
            delete instData;
      }
   }
}

// This is a semi-colon separated list
public class CartoSymInstInitList : CartoSymList<CartoSymMemberInitList>
{
public:
   StylesMask mask;

   CartoSymInstInitList ::parse(CartoSymLexer lexer)
   {
      return (CartoSymInstInitList)CartoSymList::parse(class(CartoSymInstInitList), lexer, CartoSymMemberInitList::parse, 0);
   }

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      CartoSymList::print(out, indent, o);
   }

   // getStyle2() is same as getStyle() but splits up the unit value and unit (e.g. Meters) separately
   CartoSymExpression getStyle2(StylesMask msk, Class * uc)
   {
      CartoSymExpression result = getStyle(msk);
      while(result && result._class == class(CartoSymExpInstance))
      {
         CartoSymExpInstance ei = (CartoSymExpInstance)result;
         if(uc && ei.instance && ei.instance._class)
         {
            CartoSymSpecName sn = (CartoSymSpecName)ei.instance._class;
            Class c = sn ? eSystem_FindClass(__thisModule, sn.name) : null;
            if(c && c.type == unitClass && c.base.type == unitClass)
            {
               *uc = c;
               msk = 0;
            }
         }
         else
            result = null;

         if(ei.instance && ei.instance.members)
         {
            // NOTE: This piece and the while loop should no longer be required now with findDeepStyle()
            // TODO: Should iterate from the last?
            for(i : ei.instance.members)
            {
               CartoSymMemberInitList members = i;
               CartoSymMemberInit mInit = members ? members.findDeepStyle(msk) : null;
               if(mInit)
               {
                  result = mInit.initializer;
                  break;
               }
            }
         }
      }
      return result;
   }

   CartoSymMemberInit findStyle(StylesMask msk)
   {
      // if(mask & this.mask)
      {
         Iterator<CartoSymMemberInitList> it { this };
         while(it.Prev())
         {
            CartoSymMemberInitList e = it.data;
            CartoSymMemberInit mInit = e.findStyle(msk);
            if(mInit) return mInit;
         }
      }
      return null;
   }

   CartoSymMemberInit findDeepStyle(StylesMask msk)
   {
      // if(mask & this.mask)
      {
         Iterator<CartoSymMemberInitList> it { this };
         while(it.Prev())
         {
            CartoSymMemberInitList e = it.data;
            CartoSymMemberInit mInit = e.findDeepStyle(msk);
            if(mInit) return mInit;
         }
      }
      return null;
   }

   void removeStyle(StylesMask msk)
   {
      Iterator<CartoSymMemberInitList> it { this };
      it.Next();
      while(it.pointer)
      {
         IteratorPointer next = it.container.GetNext(it.pointer);
         CartoSymMemberInitList memberInitList = it.data;
         memberInitList.removeStyle(msk);
         if(memberInitList.GetCount() == 0)
         {
            it.Remove();
            delete memberInitList;
         }
         it.pointer = next;
      }
      mask &= ~msk; // todo: make sure this is ok or write a mask recalculation function?
   }

   CartoSymExpression getStyle(StylesMask mask)
   {
      CartoSymMemberInit mInit = findDeepStyle(mask);
      return mInit ? mInit.initializer : null;
   }

   void setMemberValue(Class c, const String idsString, StylesMask mask, bool createSubInstance, const FieldValue value, Class uc)
   {
      setMember2(c, idsString, mask, createSubInstance, expressionFromValue(value, uc), null, null, none);
   }

   void setMemberValue2(Class c, const String idsString, StylesMask mask, bool createSubInstance, const FieldValue value, Class uc, ECCSSEvaluator evaluator, Class stylesClass)
   {
      setMember2(c, idsString, mask, createSubInstance, expressionFromValue(value, uc), evaluator, stylesClass, none);
   }

   void setMember(Class c, const String idString, StylesMask msk, bool createSubInstance, CartoSymExpression expression)
   {
      if(expression)
         setMember2(c, idString, msk, createSubInstance, expression, null, null, none);
      else
         removeStyle(msk); // TOCHECK: Should the style be removed if attempting to set a null expression?
   }

   void setMember2(Class c, const String idString, StylesMask msk, bool createSubInstance, CartoSymExpression expression, ECCSSEvaluator evaluator, Class stylesClass, CartoSymTokenType tt)
   {
      if(this)
      {
         CartoSymMemberInitList list = null;
         if(msk)
         {
            Iterator<CartoSymMemberInitList> it { this };
            char * dot = idString ? strchr(idString, '.') : null;
            String member = null;
            if(dot)
            {
               int len = (int)(dot - idString);
               member = new char[len+1];
               memcpy(member, idString, len);
               member[len] = 0;
            }

            /*StylesMask topMask = msk;
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
               CartoSymMemberInitList members = it.data;
               if(member && members.findTopStyle(mask, member))
               {
                  list = members;
                  break;
               }

               if(members.findStyle(msk))
               {
                  list = members;
                  break;
               }
            }
            delete member;
         }
         if(!list)
            Add((list = { }));

         list.setMember2(c, idString, msk, createSubInstance, expression, evaluator, stylesClass, tt);

         mask |= msk;
      }
   }

   bool changeStyle(StylesMask msk, const FieldValue value, Class c, ECCSSEvaluator evaluator, bool isNested, Class uc)
   {
      const String idString = msk ? evaluator.evaluatorClass.stringFromMask(msk, c) : null;
      CartoSymExpression e = expressionFromValue(value, uc);
      FieldValue v { };

      setMember2(c, idString, msk, !isNested, e, evaluator, c, none);
      e.compute(v, evaluator, preprocessing, c); // REVIEW: use of c for stylesClass here...
      return true;
   }
}

public class CartoSymInstantiation : CartoSymNode
{
public:
   CartoSymSpecName _class;

   CartoSymInstInitList members;

   CartoSymInstantiation ::parse(CartoSymSpecName spec, CartoSymLexer lexer)
   {
      CartoSymInstantiation inst { _class = spec };
      lexer.readToken();
      inst.members = CartoSymInstInitList::parse(lexer);
      if(lexer.peekToken().type == '}')
         lexer.readToken();
      return inst;
   }

   CartoSymInstantiation copy()
   {
      CartoSymInstantiation o { _class = _class ? _class.copy() : null, members = members ? members.copy() : null };
      return o;
   }

   void print(File out, int indent, CartoSymOutputOptions o)
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
            Iterator<CartoSymMemberInitList> it { members };
            while(it.Next())
            {
               CartoSymMemberInitList init = it.data;
               printIndent(indent, out);
               init.print(out, indent, o);
               // REVIEW: When we want this semicolon?
               if(init._class == class(CartoSymMemberInitList) && members.GetNext(it.pointer))
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


   ~CartoSymInstantiation()
   {
      delete _class;

      delete members;
   }
};

public class CartoSymMemberInit : CartoSymNode
{
   class_no_expansion;
public:
   List<CartoSymIdentifier> identifiers;
   CartoSymExpression initializer;

   CartoSymTokenType assignType;
   Class destType;
   StylesMask stylesMask;
   DataMember dataMember;
   uint offset;

   CartoSymMemberInit ::parse(CartoSymLexer lexer)
   {
      List<CartoSymIdentifier> identifiers = null;
      CartoSymExpression initializer = null;
      CartoSymTokenType assignType = '=';
      if(lexer.peekToken().type == identifier)
      {
         int a = lexer.pushAmbiguity();
         while(true)
         {
            CartoSymIdentifier id = CartoSymIdentifier::parse(lexer);
            if(id)
            {
               if(!identifiers) identifiers = { };
               identifiers.Add(id);
               if(lexer.peekToken().type != '.')
                  break;
               else
                  lexer.readToken();
            }
         }
         if(lexer.peekToken().type == '=' || lexer.nextToken.type == addAssign)
         {
            assignType = lexer.nextToken.type;
            lexer.clearAmbiguity();
            lexer.readToken();
         }
         else
         {
            identifiers.Free();
            delete identifiers;
            lexer.popAmbiguity(a);
         }
      }
      initializer = CartoSymExpression::parse(lexer);  /*CartoSymInitExp*/
      return (identifiers || initializer) ?
         CartoSymMemberInit { identifiers = (void *)identifiers, initializer = initializer, assignType = assignType } : null;
   }

   CartoSymNode copy()
   {
      CartoSymMemberInit memberInit
      {
         assignType = assignType, initializer = initializer.copy(), stylesMask = stylesMask,
         identifiers = copyList(identifiers, (void *)CartoSymIdentifier::copy),
         destType = destType, dataMember = dataMember,
         offset = offset
      };
      return memberInit;
   }

   // targetStylesMask is topMask for the 'c' instance (e.g. stroke for stroke =)
   private ExpFlags precompute(Class stylesClass, Class c, StylesMask targetStylesMask, int * memberID, ECCSSEvaluator evaluator)
   {
      ExpFlags flags = 0;
      // NOTE: We need a separate Class for the styling object within which a sub-instance would be
      //       vs. the current instance level class (current c)
      String identifierStr = targetStylesMask ? CopyString(evaluator.evaluatorClass.stringFromMask(targetStylesMask, stylesClass)) : null;
      Class type = c;

      dataMember = null;
      if(type && identifiers && identifiers.first)
      {
         for(i : identifiers)
         {
            String s = identifierStr ? PrintString(identifierStr, ".", i.string) : CopyString(i.string);
            delete identifierStr;
            identifierStr = s;
            dataMember = eClass_FindDataMember(type, i.string, type.module, null, null);
            if(!dataMember)
            {
               dataMember = (DataMember)eClass_FindProperty(type, i.string, type.module);
            }
            if(dataMember)
            {
               if(!dataMember.dataTypeClass)
                  dataMember.dataTypeClass = destType = eSystem_FindClass(dataMember._class.module, dataMember.dataTypeString);
               else
                  destType = dataMember.dataTypeClass;
               type = dataMember.dataTypeClass;
            }
         }
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

         stylesMask = identifierStr && stylesClass && stylesClass.type != structClass && destType != class(byte)
            ? evaluator.evaluatorClass.maskFromString(identifierStr, stylesClass) : 0;
         if(initializer)
         {
            CartoSymExpression e = initializer;
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
                  if(e._class == class(CartoSymExpInstance))
                  {
                     ((CartoSymExpInstance)e).targetMask = stylesMask;
                  }
                  else if(e._class == class(CartoSymExpConditional))
                  {
                     CartoSymExpConditional cond = (CartoSymExpConditional)e;
                     CartoSymExpression lastExp = cond.expList ? cond.expList.lastIterator.data : null;
                     if(lastExp && lastExp._class == class(CartoSymExpInstance))
                     {
                        ((CartoSymExpInstance)lastExp).targetMask = stylesMask;
                     }
                     if(cond.elseExp && cond.elseExp._class == class(CartoSymExpInstance))
                     {
                        ((CartoSymExpInstance)cond.elseExp).targetMask = stylesMask;
                     }
                  }
                  flags = e.compute(val, evaluator, preprocessing, stylesClass);
               }
               if(flags.resolved)
                  initializer = simplifyResolved(val, e);
            }
         }
      }
      else if(type && type.type == unitClass)
      {
         stylesMask = identifierStr && stylesClass && stylesClass.type != structClass
            ? evaluator.evaluatorClass.maskFromString(identifierStr, stylesClass) : 0;
         if(initializer)
         {
            CartoSymExpression e = initializer;
            if(e)
            {
               FieldValue val { };
               e.destType = type;
               if(e._class == class(CartoSymExpInstance))
                  ((CartoSymExpInstance)e).targetMask = stylesMask;
               flags = e.compute(val, evaluator, preprocessing, stylesClass);
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

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      print2(out, indent, o, null);
   }

   void print2(File out, int indent, CartoSymOutputOptions o, DataMember lastMember)
   {
      bool outputIdentifiers = false;
      if(identifiers)
      {
         outputIdentifiers = true;
         if(identifiers.count == 1 && o.skipImpliedID && dataMember)
         {
            if((!lastMember && dataMember.id == 0) || (lastMember && dataMember.id == lastMember.id + 1))
               outputIdentifiers = false;
         }
      }

      if(outputIdentifiers)
      {
         Iterator<CartoSymIdentifier> it { identifiers };
         CartoSymExpInstance ei = initializer && initializer._class == class(CartoSymExpInstance) ? (CartoSymExpInstance)initializer : null;
         Class type = ei ? (ei.expType ? ei.expType : ei.destType) : null;
         bool slType = !type || type.type == structClass || type.type == unitClass || type.type == bitClass || type.type == noHeadClass;

         if(type && type.type == structClass && !strcmp(type.name, "HillShading")) // Make an exception until we switch to noHeadClass
            slType = false;

         while(it.Next())
         {
            it.data.print(out, indent, o);
            if(identifiers.GetNext(it.pointer))
               out.Print(".");
         }
         out.Print(" ");
         assignType.print(out, indent, o);
         if(slType && (!initializer || initializer._class != class(CartoSymExpInstance) || !((CartoSymExpInstance)initializer).printsAsMultiline))
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

   ~CartoSymMemberInit()
   {
      if(identifiers)
         identifiers.Free(), delete identifiers;
      delete initializer;
   }
};

// This is a comma-separated list
public class CartoSymMemberInitList : CartoSymList<CartoSymMemberInit>
{
public:
   //StylesMask stylesMask;
   CartoSymMemberInitList ::parse(CartoSymLexer lexer)
   {
      CartoSymMemberInitList list = (CartoSymMemberInitList)CartoSymList::parse(class(CartoSymMemberInitList), lexer, CartoSymMemberInit::parse, ',');
      if(lexer.peekToken().type == ';')
         lexer.readToken();
      return list;
   }

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      Iterator<CartoSymMemberInit> it { list };
      DataMember lastMember = null;
      while(it.Next())
      {
         CartoSymMemberInit init = it.data;
         init.print2(out, indent, o, lastMember);
         lastMember = init.dataMember;
         if(list.GetNext(it.pointer))
         {
            // NOTE: can multiLineInstance keep 'true' from call to CartoSymExpInstance::print?
            if(o.multiLineInstance || init.assignType == addAssign)
            {
               out.PrintLn(",");
               printIndent(indent, out);
            }
            else
               printSep(out);
         }
      }
   }

   CartoSymExpression getMemberByIDs(Container<const String> ids)
   {
      return getMemberByIDs2(ids, null);
   }

   CartoSymExpression getMemberByIDs2(Container<const String> ids, CartoSymMemberInit * initPtr)
   {
      CartoSymExpression result = null;
      // TODO: Recognize default initializers
      for(mi : this)
      {
         CartoSymMemberInit init = mi;
         if(init && init.initializer)
         {
            CartoSymExpression e = init.initializer;
            bool same = true;
            if(ids.GetCount() != (init.identifiers ? init.identifiers.count : 0))
               same = false;
            else
            {
               int j;
               Iterator<CartoSymIdentifier> it { init.identifiers };

               for(j = 0; j < ids.GetCount(); j++)
               {
                  const String id = ids[j], s = it.Next() ? it.data.string : null;
                  if(!s || strcmp(s, id))
                  {
                     same = false;
                     break;
                  }
               }
            }
            if(same)
            {
               result = e;
               if(initPtr) *initPtr = init;
            }
         }
      }
      return result;
   }

   private static bool setSubMember(bool createSubInstance, Class c, const String idsString, StylesMask mask, CartoSymExpression expression,
      CartoSymMemberInit * mInitPtr, ECCSSEvaluator evaluator, Class stylesClass, CartoSymTokenType tt)
   {
      CartoSymMemberInit mInit = null;
      CartoSymMemberInit mInit2 = null;
      bool setSubInstance = false;

      if(idsString && idsString[0])
      {
         char * dot = strchr(idsString, '.');
         String member = null;
         if(dot)
         {
            int len = (int)(dot - idsString);
            CartoSymExpression e = null;

            member = new char[len+1];

            memcpy(member, idsString, len);
            member[len] = 0;

            if(this && tt != addAssign) //
            {
               e = getMemberByIDs2([ member ], &mInit2); // TOCHECK: Is this still needed?
               if(!e && mask)
               {
                  // This will recognize default initializers...
                  CartoSymMemberInit mInit = findTopStyle(mask, member);
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
                        mInit = findStyle(mask);
                        if(mInit) e = mInit.initializer;
                     }
                  }
               }
            }

            if(!e && createSubInstance)
            {
               e = CartoSymExpInstance { };
               if(evaluator != null)
               {
                  // NOTE: If we have the evaluator here, we can set targetMask for ExpInstance, as we should...
                  ((CartoSymExpInstance)e).targetMask = evaluator.evaluatorClass.maskFromString(member, stylesClass);
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

               ((CartoSymExpInstance)e).setMember(dot+1, mask, createSubInstance, expression);
               expression = e;
               idsString = member;
            }
            else if(e && e._class == class(CartoSymExpInstance) && !setSubInstance)
            {
               ((CartoSymExpInstance)e).setMember(dot+1, mask, createSubInstance, expression);
               setSubInstance = true;

               if(mInit2)
                  mInit2.stylesMask |= mask;
            }
         }

         if(!setSubInstance && mInitPtr)
         {
            // NOTE: The mask being set here should be the full mask if expression is a CartoSymExpInstance (but requires the targetMask to be set)
            if(expression && expression._class == class(CartoSymExpInstance))
            {
               mask |= ((CartoSymExpInstance)expression).targetMask;
            }

            mInit =
            {
               initializer = expression,
               // identifiers = { }, // FIXME: #1220
               assignType = tt == addAssign ? addAssign : equal,
               stylesMask = mask;
            };
            if(expression && mInit.destType) expression.destType = mInit.destType;

            mInit.identifiers = { };

            if(dot)
            {
               Array<String> split = dot ? splitIdentifier(idsString) : { [ CopyString(idsString) ] };
               DataMember dataMember = null;
               for(s : split)
               {
                  mInit.identifiers.Add(CartoSymIdentifier { string = s });
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
               mInit.identifiers.Add({ string = CopyString(idsString) });
            }
         }
         delete member;
      }
      if(mInitPtr && !setSubInstance)
         *mInitPtr = mInit;
      return setSubInstance;
   }

   bool removeByIDs(const String idsString, StylesMask mask, IteratorPointer * after)
   {
      bool result = false;
      char * dot = idsString ? strchr(idsString, '.') : null;
      Array<String> split = dot ? splitIdentifier(idsString ? idsString : "") : { [ CopyString(idsString) ] };
      Iterator<CartoSymMemberInit> itmi { this };

      itmi.Next();
      while(itmi.pointer)
      {
         IteratorPointer next = GetNext(itmi.pointer);
         CartoSymMemberInit oldMInit = itmi.data;
         bool same = true;

         if(oldMInit.identifiers && split.count)
         {
            if(oldMInit.identifiers.count != split.count)
               same = false;
            else
            {
               Iterator<String> itId { split };
               itId.Next();
               for(i : oldMInit.identifiers)
               {
                  CartoSymIdentifier oldID = i;
                  String newID = itId.data;
                  if(!newID || !oldID.string || strcmp(newID, oldID.string))
                  {
                     same = false;
                     break;
                  }
               }
            }
         }
         else if((oldMInit.identifiers && !split.count) || (!oldMInit.identifiers && split.count))
         {
            if(!oldMInit.identifiers && split.count == 1 && mask && oldMInit.stylesMask == mask)
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

   void setMember(Class c, const String idsString, StylesMask mask, bool createSubInstance, CartoSymExpression expression)
   {
      setMember2(c, idsString, mask, createSubInstance, expression, null, null, none);
   }

   void setMember2(Class c, const String idsString, StylesMask mask, bool createSubInstance, CartoSymExpression expression, ECCSSEvaluator evaluator, Class stylesClass, CartoSymTokenType tt)
   {
      CartoSymMemberInit mInit;

      if(!setSubMember(createSubInstance, c, idsString, mask, expression, &mInit, evaluator, stylesClass, tt))
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
   CartoSymMemberInit findStyle(StylesMask mask)
   {
      //if(mask & stylesMask)
      {
         Iterator<CartoSymMemberInit> it { this };
         while(it.Prev())
         {
            CartoSymMemberInit mInit = it.data;
            StylesMask sm = mInit.stylesMask;
            if(!mask || (sm & mask))   // NOTE: Useful to pass a 0 mask to look for unit class value
               return mInit;
         }
      }
      return null;
   }

   // Returns the top style matching topID requested, using sub-value mask to avoid unneeded comparisons
   CartoSymMemberInit findTopStyle(StylesMask mask, const String topID)
   {
      //if(mask & stylesMask)
      {
         Iterator<CartoSymMemberInit> it { this };
         while(it.Prev())
         {
            CartoSymMemberInit mInit = it.data;
            StylesMask sm = mInit.stylesMask;
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
   CartoSymMemberInit findExactStyle(StylesMask mask)
   {
      //if(mask & stylesMask)
      {
         Iterator<CartoSymMemberInit> it { this };
         while(it.Prev())
         {
            CartoSymMemberInit mInit = it.data;
            StylesMask sm = mInit.stylesMask;
            if(sm == mask)
               return mInit;
         }
      }
      return null;
   }

   // Returns an expression exactly for requested mask, including from sub-instance, or null
   CartoSymMemberInit findDeepStyle(StylesMask mask)
   {
      //if(mask & stylesMask)
      {
         Iterator<CartoSymMemberInit> it { this };
         while(it.Prev())
         {
            CartoSymMemberInit mInit = it.data;
            StylesMask sm = mInit.stylesMask;
            if(sm == mask)
               return mInit;
            else if(sm & mask)
            {
               if(mInit.initializer && mInit.initializer._class == class(CartoSymExpInstance))
               {
                  CartoSymExpInstance ei = (CartoSymExpInstance)mInit.initializer;
                  mInit = ei.instance && ei.instance.members ? ei.instance.members.findDeepStyle(mask) : null;
               }
               else
                  mInit = null;
               return mInit;
            }
         }
      }
      return null;
   }

   void removeStyle(StylesMask mask)
   {
      Iterator<CartoSymMemberInit> it { this };
      it.Next();
      while(it.pointer)
      {
         IteratorPointer next = it.container.GetNext(it.pointer);
         CartoSymMemberInit memberInit = it.data;
         if(memberInit.stylesMask & mask)
         {
            if((memberInit.stylesMask & mask) == memberInit.stylesMask)
            {
               it.Remove();
               delete memberInit;
            }
            else
            {
               CartoSymExpression e = memberInit.initializer;
               if(e._class == class(CartoSymExpInstance))
               {
                  CartoSymExpInstance inst = (CartoSymExpInstance)e;
                  // FIXME: stylesMask is not always set after a changeStyle() ?  if(inst.stylesMask & mask)
                  {
                     CartoSymInstInitList initList = inst.instance ? inst.instance.members : null;
                     if(initList)
                     {
                        Iterator<CartoSymMemberInitList> itl { initList };
                        itl.Next();
                        while(itl.pointer)
                        {
                           IteratorPointer nextL = itl.container.GetNext(itl.pointer);
                           CartoSymMemberInitList mInitList = itl.data;
                           if(mInitList)
                           {
                              mInitList.removeStyle(mask);
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
                  if(e._class != class(CartoSymExpInstance))
                     memberInit.stylesMask &= ~(memberInit.stylesMask & mask);
               }
            }
         }
         it.pointer = next;
      }
   }

   CartoSymMemberInitList copy()
   {
      CartoSymMemberInitList c = null;
      if(this)
      {
         c = eInstance_New(_class);
         for(n : this)
            c.Add(n.copy());
      }
      return c;
   }
}

public class CartoSymSpecName : CartoSymNode
{
   class_no_expansion;

public:
   String name;

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      if(name) out.Print(name);
   }

   CartoSymSpecName copy()
   {
      CartoSymSpecName spec { name = CopyString(name) };
      return spec;
   }

   ~CartoSymSpecName()
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

public CartoSymExpression expressionFromValue(const FieldValue value, Class c)
{
   CartoSymExpression e = null;
   if(c && value.type.type == blob && value.b != null)
   {
      if(eClass_IsDerived(c, class(Container)) && c.templateArgs && c.templateArgs[0].dataTypeString)
      {
         // Arrays / Containers
         Container container = (Container)value.b;
         uint count = container.GetCount();
         CartoSymList<CartoSymExpression> elements { };
         CartoSymExpArray array { elements = elements, destType = c };
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
               CartoSymExpression ee = null;
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
            CartoSymInstantiation instance { };
            CartoSymExpInstance ei { instance = instance };

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
                     StylesMask mask = 0; //evaluator.evaluatorClass.
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
                     // WARNING: We don't have evaluator and stylesClass to properly set targetMask here yet...
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
            CartoSymExpIdentifier { identifier = { string = CopyString("null") } } :
         value.type.type == text ? CartoSymExpString { string = CopyString(value.s) } :
         CartoSymExpConstant { destType = c, constant = value };
      if(c && c.type == unitClass && c.base && c.base.type == unitClass && e._class == class(CartoSymExpConstant))
      {
         String s = CopyString(c.name);
         CartoSymMemberInit minit { initializer = e };
         CartoSymMemberInitList memberInitList { [ minit ] };
         CartoSymInstantiation instantiation
         {
            _class = CartoSymSpecName { name = CopyString(s) }, // e.g. "Meters"
            members = { [ memberInitList ] }
         };
         e.destType = null;
         e = CartoSymExpInstance { destType = c, instance = instantiation };
      }
   }
   return e;
}
