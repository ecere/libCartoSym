public import IMPORT_STATIC "ecrt"

private:

public struct DateTimeInterval
{
   DateTime start /* or instant */, end;

   property TimeIntervalSince1970
   {
      get
      {
         value.start = start.year ? start : earliestTime;
         value.end   = end.year   ? end   : latestTime;
      }

      set
      {
         start = value.start <= earliestTime ? { } : value.start;
         end   = value.end = latestTime || value.end == unsetTime ? { } : value.end;
      }
   }
};

public define unsetTime = MININT64;
public define earliestTime = MININT64 + 1;
public define latestTime = MAXINT64;

public struct TimeIntervalSince1970
{
   SecSince1970 start, end;   // end is unsetTime for an Instant

   bool OnGetDataFromString(const char * string)
   {
      bool result = false;
      const char * dash = strchr(string, '-'); // Don't look for / if no - is present
      const char * slash = dash ? strchr(string, '/') : null;

      if(slash)
      {
         char sString[100];
         const char * eString = slash + 1;
         int l = Min(99, slash - string);
         strncpy(sString, string, l);
         sString[l] = 0;
         if(sString[0] == '.')
            start = earliestTime, result = true;
         else if(!start.OnGetDataFromString(sString))
            start = unsetTime;
         else
            result = true;
         if(eString[0] == '.')
            end = latestTime;
         else if(!end.OnGetDataFromString(slash + 1))
         {
            end = unsetTime;
            result = false;
         }
         else
         {
            // REVIEW: Extending time to end of day
            if(strlen(eString) <= 10)
            {
               DateTime dt = end;
               if(!dt.hour && !dt.minute && !dt.second)
               {
                  dt.hour = 23;
                  dt.minute = 59;
                  dt.second = 59;
                  end = dt;
               }
            }
         }
      }
      else
      {
         end = unsetTime;
         if(!start.OnGetDataFromString(string))
            start = unsetTime;
         else
         {
            // Expand month to whole month range
            const String dash = strchr(string, '-');
            if(dash && !strchr(dash+1, '-'))
            {
               DateTime t = start;
               t.day = t.month.getNumDays(t.year);
               t.hour = 23;
               t.minute = 59;
               t.second = 59;
               end = t;
            }
            result = true;
         }
      }
      return result;
   }

   // interval or timestamp functions
   bool equals(const TimeIntervalSince1970 b)
   {
      return start == b.start &&
         (end == unsetTime ? start : end) ==
         (b.end == unsetTime ? b.start : b.end);
   }

   bool disjoint(const TimeIntervalSince1970 b)
   {
      return before(b) || after(b);
   }

   bool after(const TimeIntervalSince1970 b)
   {
      return start > (b.end == unsetTime ? b.start : b.end);
   }

   bool before(const TimeIntervalSince1970 b)
   {
      return (end == unsetTime ? start : end) < b.start;
   }

   bool intersects(const TimeIntervalSince1970 b)
   {
      return !disjoint(b);
   }

   //interval-only functions
   bool contains(const TimeIntervalSince1970 b)
   {
      return start < b.start && end > b.end;
   }

   bool during(const TimeIntervalSince1970 b)
   {
      return start > b.start && end < b.end;
   }

   bool finishedby(const TimeIntervalSince1970 b)
   {
      return start < b.start && end == b.end;
   }

   bool finishes(const TimeIntervalSince1970 b)
   {
      return start > b.start && end == b.end;
   }

   bool meets(const TimeIntervalSince1970 b)
   {
      return end == b.start;
   }

   bool metby(const TimeIntervalSince1970 b)
   {
      return start == b.end;
   }

   bool overlappedby(const TimeIntervalSince1970 b)
   {
      return start > b.start && start < b.end && end > b.end;
   }

   bool overlaps(const TimeIntervalSince1970 b)
   {
      return start < b.start && end > b.start && end < b.end;
   }

   bool startedby(const TimeIntervalSince1970 b)
   {
      return start == b.start && end > b.end;
   }

   bool starts(const TimeIntervalSince1970 b)
   {
      return start == b.start && end < b.end;
   }
};
