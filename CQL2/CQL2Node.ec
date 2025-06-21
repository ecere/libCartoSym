public import "CQL2Lexing"

public void printIndent(int indent, File out)
{
   int i;
   for(i = 0; i < indent; i++)
      out.Print("   ");
}

public class CQL2Node : Container
{
   // We don't want to compare contents of these nodes
   class_no_expansion;
   int OnCompare(CQL2Node b)
   {
      if(this < b) return -1;
      if(this > b) return  1;
      return 0;
   }

public:
   virtual void print(File out, int indent, CQL2OutputOptions o);
   virtual void * copy() { return null; }
   String toString(CQL2OutputOptions o)
   {
      TempFile f { };
      String s;
      print(f, 0, o);
      f.Putc(0);
      s = (String)f.StealBuffer();
      delete f;
      return s;
   }

   ~CQL2Node()
   {
      if(this)
         Free();
   }
}

public class CQL2List : CQL2Node
{
public:
   List<CQL2Node> list { };

   IteratorPointer GetFirst()                             { return list ? list.GetFirst() : 0; }
   IteratorPointer GetLast()                              { return list ? list.GetLast() : 0; }
   IteratorPointer GetPrev(IteratorPointer pointer)       { return list ? list.GetPrev(pointer) : 0; }
   IteratorPointer GetNext(IteratorPointer pointer)       { return list ? list.GetNext(pointer) : 0; }
   bool SetData(IteratorPointer pointer, D data)          { return list ? list.SetData(pointer, (CQL2Node)data) : 0; }
   D GetData(IteratorPointer pointer)                     { return list ? list.GetData(pointer) : (D)0; }
   IteratorPointer GetAtPosition(I pos, bool create, bool * justAdded)      { return list ? list.GetAtPosition((int)pos, create, justAdded) : 0; }
   IteratorPointer Insert(Link after, T value)            { return list ? list.Insert(after, (void *)value) : 0; }
   IteratorPointer Add(T value)                           { return list ? list.Add((void *)value) : 0; }
   void Remove(IteratorPointer it)                        { if(list) list.Remove(it); }
   void Move(IteratorPointer it, IteratorPointer after)   { if(list) list.Move(it, after); }
   void RemoveAll()                                       { if(list) list.RemoveAll(); }
   void Copy(Container<T> source)                         { if(list) list.Copy(source); }
   IteratorPointer Find(D value)                          { return list ? list.Find((void *)value) : 0; }
   void FreeIterator(IteratorPointer it)                  { if(list) list.FreeIterator(it); }
   int GetCount()                                         { return list ? list.GetCount() : 0; }
   void Free()                                            { if(list) list.Free(); }
   void Delete(IteratorPointer i)                         { if(list) list.Delete(i); }

public:
   void OnFree()
   {
      Free();
      delete list;
      delete this;
   }

   virtual void printSep(File out)
   {
      out.Print(", ");
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      Iterator<CQL2Node> it { list };
      while(it.Next())
      {
         it.data.print(out, indent, o);
         if(list.GetNext(it.pointer))
            printSep(out);
      }
   }

   Container ::parse(subclass(Container) c, CQL2Lexer lexer, CQL2Node parser(CQL2Lexer lexer), char sep)
   {
      Container<CQL2Node> list = null;
      while(true)
      {
         CQL2Node e = parser(lexer);
         if(e)
         {
            if(!list) list = eInstance_New(c);
            list.Add(e);
         }
         else
            break;
         lexer.peekToken();
         if(sep && lexer.nextToken.type == sep)
            lexer.readToken();
         else if(sep || lexer.nextToken.type == '}' || !lexer.nextToken.type)
            break;
      }
      return list;
   }

   ~CQL2List()
   {
      Free();
   }

   CQL2List copy()
   {
      CQL2List l = null;
      if(this)
      {
         l = eInstance_New(_class);
         if(list)
         {
            for(n : list)
               l.list.Add(n.copy());
         }
      }
      return l;
   }
}


// NOTE: The 'len' is a stop on the SOURCE string, and these functions are missing a stop on the destination string
public int UnescapeCQL2String(char * d, const char * s, int len)
{

   int j = 0, k = 0;
   char ch;
   bool continuing = false; // For continuing between character literal parts
   while(j < len && (ch = s[j]))
   {
      if(continuing)
      {
         if(ch == '\'')
            continuing = false;
         j++;
         continue;
      }
      else if(ch == '\\')
      {
         switch((ch = s[++j]))
         {
            case 'n': d[k] = '\n'; break;
            case 't': d[k] = '\t'; break;
            case 'a': d[k] = '\a'; break;
            case 'b': d[k] = '\b'; break;
            case 'f': d[k] = '\f'; break;
            case 'r': d[k] = '\r'; break;
            case 'v': d[k] = '\v'; break;
            case '\\': d[k] = '\\'; break;
            case '\"': d[k] = '\"'; break;
            case '\'': d[k] = '\''; break;
            default: d[k] = '\\'; d[k] = ch;
         }
      }
      else
      {
         if(ch == '\'' && s[j+1] == '\'')
            j++;
         else if(ch == '\'')
         {
            continuing = true;
            j++;
            continue;
         }
         d[k] = ch;
      }

      j++, k++;
   }
   d[k] = '\0';
   return k;
}

String copyEscapeCQL2(String string)
{
   String result = null;
   if(string)
   {
      String buffer = new char[strlen(string) * 2 + 1];
      char * s = string;
      char * d = buffer;
      while(*s)
      {
         switch(*s)
         {
            case '\n': *d = '\\'; d++; *d = 'n'; break;
            case '\'': *d = '\''; d++; *d = '\''; break;
            default: *d = *s;
         }
         s++;
         d++;
      }
      *d = '\0';
      result = CopyString(buffer);
      delete buffer;
   }
   return result;
}
