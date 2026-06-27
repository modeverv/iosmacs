/* iosmacs_ncurses_stub.c — minimal ncurses/termcap stub for GNU Emacs NW
   on Android without the HAVE_ANDROID text-terminal restriction.

   Implements only the subset of termcap/terminfo that GNU Emacs uses when
   started as an interactive text-terminal process (TERM=xterm-256color).
   All xterm-256color capability strings are hardcoded; no runtime database
   lookup is performed.

   This stub is compiled into a static library (libncurses.a) and linked
   into the NW Emacs cross-build for Android ARM64.  */

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

/* ------------------------------------------------------------------ */
/* Global termcap variables required by some callers.                  */
/* ------------------------------------------------------------------ */

char PC = '\0';
char *BC = NULL;
char *UP = NULL;
short ospeed = 0;

/* ------------------------------------------------------------------ */
/* Internal capability tables                                          */
/* ------------------------------------------------------------------ */

/* Termcap (old-style) string capabilities for xterm-256color.
   Uses termcap %-parameter syntax: %i increments both args; %d prints
   decimal; the GNU Emacs tparam.c handles substitution via tgoto().  */
static const struct { const char *id; const char *value; } tc_str[] = {
  { "cm", "\033[%i%d;%dH"  },   /* cursor_address */
  { "cl", "\033[H\033[2J"  },   /* clear_screen */
  { "ce", "\033[K"          },   /* clr_eol */
  { "cd", "\033[J"          },   /* clr_eos */
  { "ho", "\033[H"          },   /* cursor_home */
  { "al", "\033[L"          },   /* insert_line */
  { "dl", "\033[M"          },   /* delete_line */
  { "AL", "\033[%dL"        },   /* parm_insert_line */
  { "DL", "\033[%dM"        },   /* parm_delete_line */
  { "ic", "\033[@"          },   /* insert_character */
  { "dc", "\033[P"          },   /* delete_character */
  { "IC", "\033[%d@"        },   /* parm_ich */
  { "DC", "\033[%dP"        },   /* parm_dch */
  { "sf", "\n"              },   /* scroll_forward */
  { "sr", "\033M"           },   /* scroll_reverse */
  { "SF", "\033[%dS"        },   /* parm_index */
  { "SR", "\033[%dT"        },   /* parm_rindex */
  { "so", "\033[7m"         },   /* enter_standout_mode */
  { "se", "\033[27m"        },   /* exit_standout_mode */
  { "us", "\033[4m"         },   /* enter_underline_mode */
  { "ue", "\033[24m"        },   /* exit_underline_mode */
  { "md", "\033[1m"         },   /* enter_bold_mode */
  { "mr", "\033[7m"         },   /* enter_reverse_mode */
  { "me", "\033[m"          },   /* exit_attribute_mode */
  { "mb", "\033[5m"         },   /* enter_blink_mode */
  { "mh", "\033[2m"         },   /* enter_dim_mode */
  { "mk", "\033[8m"         },   /* enter_secure_mode */
  { "ti", "\033[?1049h"     },   /* enter_ca_mode */
  { "te", "\033[?1049l"     },   /* exit_ca_mode */
  { "vs", "\033[?12l\033[?25h" }, /* cursor_visible */
  { "vi", "\033[?25l"       },   /* cursor_invisible */
  { "ve", "\033[?12l\033[?25h" }, /* cursor_normal */
  { "ks", "\033[?1h\033="   },   /* keypad_xmit */
  { "ke", "\033[?1l\033>"   },   /* keypad_local */
  { "cs", "\033[%i%d;%dr"   },   /* change_scroll_region */
  { "bl", "\007"            },   /* bell */
  { "cr", "\r"              },   /* carriage_return */
  { "ta", "\t"              },   /* tab */
  { "le", "\010"            },   /* cursor_left */
  { "nd", "\033[C"          },   /* cursor_right */
  { "up", "\033[A"          },   /* cursor_up */
  { "do", "\012"            },   /* cursor_down */
  { "bt", "\033[Z"          },   /* back_tab */
  /* 256-color set */
  { "AF", "\033[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e38;5;%p1%d%;m" },
  { "AB", "\033[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e48;5;%p1%d%;m" },
  /* Function keys */
  { "k1",  "\033OP"   }, { "k2",  "\033OQ"   }, { "k3",  "\033OR"   },
  { "k4",  "\033OS"   }, { "k5",  "\033[15~" }, { "k6",  "\033[17~" },
  { "k7",  "\033[18~" }, { "k8",  "\033[19~" }, { "k9",  "\033[20~" },
  { "k;",  "\033[21~" }, { "F1",  "\033[23~" }, { "F2",  "\033[24~" },
  /* Arrow keys */
  { "kl",  "\033[D" }, { "kr",  "\033[C" }, { "ku",  "\033[A" },
  { "kd",  "\033[B" },
  /* Editing keys */
  { "kh",  "\033[H"  }, { "@7", "\033[F"  }, { "kP",  "\033[5~" },
  { "kN",  "\033[6~" }, { "kI",  "\033[2~" }, { "kD",  "\033[3~" },
  /* Keypad */
  { "K1",  "\033[H"  }, { "K3",  "\033[5~" }, { "K4",  "\033[F"  },
  { "K5",  "\033[6~" },
  { NULL, NULL }
};

/* Termcap (old-style) numeric capabilities for xterm-256color.  */
static const struct { const char *id; int value; } tc_num[] = {
  { "co", 80 },
  { "li", 24 },
  { "sg", 0  },
  { "ug", 0  },
  { NULL, 0  }
};

/* Termcap (old-style) boolean capabilities for xterm-256color.  */
static const struct { const char *id; int value; } tc_flag[] = {
  { "am",  1 }, /* auto_right_margin */
  { "km",  1 }, /* has_meta_key */
  { "mi",  1 }, /* move_insert_mode */
  { "ms",  1 }, /* move_standout_mode */
  { "bw",  0 }, /* auto_left_margin */
  { "xs",  0 }, /* xon_xoff */
  { NULL,  0 }
};

/* Terminfo string capabilities for xterm-256color.
   These are queried via tigetstr() for extended attributes.  */
static const struct { const char *cap; const char *value; } ti_str[] = {
  { "smxx",  "\033[9m"                },   /* enter_strikethrough_mode */
  { "rmxx",  "\033[29m"               },   /* exit_strikethrough_mode */
  { "setf24","\033[38;2;%p1%d;%p2%d;%p3%dm" }, /* set_foreground_24bit */
  { "setb24","\033[48;2;%p1%d;%p2%d;%p3%dm" }, /* set_background_24bit */
  { "Smulx", "\033[4:%p1%dm"          },   /* set_underline_style */
  { "smcup", "\033[?1049h"            },   /* enter_ca_mode */
  { "rmcup", "\033[?1049l"            },   /* exit_ca_mode */
  { "civis", "\033[?25l"              },   /* cursor_invisible */
  { "cnorm", "\033[?12l\033[?25h"     },   /* cursor_normal */
  { "smam",  "\033[?7h"               },   /* enter_am_mode */
  { "rmam",  "\033[?7l"               },   /* exit_am_mode */
  { "cup",   "\033[%i%p1%d;%p2%dH"   },   /* cursor_address */
  { "cuu",   "\033[%p1%dA"            },   /* parm_up_cursor */
  { "cud",   "\033[%p1%dB"            },   /* parm_down_cursor */
  { "cuf",   "\033[%p1%dC"            },   /* parm_right */
  { "cub",   "\033[%p1%dD"            },   /* parm_left */
  { "setaf", "\033[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e38;5;%p1%d%;m" },
  { "setab", "\033[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e48;5;%p1%d%;m" },
  { NULL, NULL }
};

/* ------------------------------------------------------------------ */
/* Internal: is this name an xterm variant?                            */
/* ------------------------------------------------------------------ */

static int
is_xterm (const char *name)
{
  return name && (strncmp (name, "xterm", 5) == 0
                  || strncmp (name, "screen", 6) == 0
                  || strncmp (name, "tmux",   4) == 0
                  || strncmp (name, "vte",    3) == 0);
}

/* ------------------------------------------------------------------ */
/* termcap API                                                          */
/* ------------------------------------------------------------------ */

static char tgetent_name[256];

int
tgetent (char *bp, const char *name)
{
  if (!is_xterm (name))
    return 0;
  if (bp)
    bp[0] = '\0';
  strncpy (tgetent_name, name ? name : "", sizeof (tgetent_name) - 1);
  tgetent_name[sizeof (tgetent_name) - 1] = '\0';
  return 1;
}

char *
tgetstr (const char *id, char **area)
{
  for (int i = 0; tc_str[i].id; i++)
    {
      if (strcmp (tc_str[i].id, id) == 0)
        {
          const char *v = tc_str[i].value;
          if (area && *area)
            {
              char *dest = *area;
              size_t len = strlen (v);
              memcpy (dest, v, len + 1);
              *area += len + 1;
              return dest;
            }
          return (char *) v;
        }
    }
  return NULL;
}

int
tgetnum (const char *id)
{
  for (int i = 0; tc_num[i].id; i++)
    if (strcmp (tc_num[i].id, id) == 0)
      return tc_num[i].value;
  return -1;
}

int
tgetflag (const char *id)
{
  for (int i = 0; tc_flag[i].id; i++)
    if (strcmp (tc_flag[i].id, id) == 0)
      return tc_flag[i].value;
  return 0;
}

/* tputs: output a terminal string, honoring $<N> padding specs.
   For xterm the strings contain no padding delays, so we just output
   each character via the supplied putc function.  */

int
tputs (const char *str, int affcnt, int (*putcf) (int))
{
  (void) affcnt;
  if (!str)
    return 0;
  while (*str)
    {
      if (str[0] == '$' && str[1] == '<')
        {
          /* Skip delay specification: $<NUMBER> */
          str += 2;
          while (*str && *str != '>')
            str++;
          if (*str == '>')
            str++;
          continue;
        }
      putcf ((unsigned char) *str);
      str++;
    }
  return 0;
}

/* ------------------------------------------------------------------ */
/* terminfo API                                                         */
/* ------------------------------------------------------------------ */

static int setupterm_done = 0;

int
setupterm (const char *term, int fd, int *errret)
{
  (void) fd;
  if (errret)
    {
      if (!is_xterm (term))
        {
          *errret = 0;
          return -1;
        }
      *errret = 1;
    }
  setupterm_done = 1;
  return 0;
}

char *
tigetstr (const char *capname)
{
  for (int i = 0; ti_str[i].cap; i++)
    if (strcmp (ti_str[i].cap, capname) == 0)
      return (char *) ti_str[i].value;
  return (char *) -1;  /* capability not supported: per POSIX, returns (char*)-1 */
}

int
tigetflag (const char *capname)
{
  if (strcmp (capname, "am") == 0)  return 1;
  if (strcmp (capname, "km") == 0)  return 1;
  if (strcmp (capname, "xenl") == 0) return 1;
  return -1;  /* not a boolean capability */
}

int
tigetnum (const char *capname)
{
  if (strcmp (capname, "cols") == 0)  return 80;
  if (strcmp (capname, "lines") == 0) return 24;
  if (strcmp (capname, "colors") == 0) return 256;
  if (strcmp (capname, "pairs") == 0)  return 32767;
  return -2;  /* capability not supported */
}

/* set_curterm / del_curterm — needed to satisfy link references.  */
typedef struct { int dummy; } TERMINAL;
static TERMINAL stub_terminal = { 0 };
TERMINAL *cur_term = &stub_terminal;

TERMINAL *
set_curterm (TERMINAL *nterm)
{
  TERMINAL *old = cur_term;
  if (nterm)
    cur_term = nterm;
  return old;
}

int
del_curterm (TERMINAL *oterm)
{
  (void) oterm;
  return 0;
}

/* putp — output a string via tputs to stdout.  */
static int
putp_putc (int c)
{
  return putchar (c);
}

int
putp (const char *str)
{
  return tputs (str, 1, putp_putc);
}

/* ------------------------------------------------------------------ */
/* tgoto — termcap-style cursor addressing                             */
/* ------------------------------------------------------------------ */

/* tgoto(cap, col, row): substitute col and row into a termcap cursor-
   address string.  GNU Emacs calls tgoto(cm, col, row) and then passes
   the result to tputs().  We hardcode xterm cursor-address output instead
   of implementing the full termcap % engine.  */

char *
tgoto (const char *cap, int col, int row)
{
  static char buf[64];
  (void) cap;
  snprintf (buf, sizeof (buf), "\033[%d;%dH", row + 1, col + 1);
  return buf;
}

/* ------------------------------------------------------------------ */
/* tparm — terminfo-style parameter substitution                       */
/* ------------------------------------------------------------------ */

/* Minimal terminfo parameter machine for the capability strings that
   GNU Emacs actually uses with xterm-256color:
     - Cursor address: \033[%i%p1%d;%p2%dH
     - 256-color fg:   \033[38;5;%p1%dm
     - 256-color bg:   \033[48;5;%p1%dm
     - Param move:     \033[%p1%dA etc.
   Supports: %p1..%p9 (push param), %i (increment p1,p2), %d (pop decimal),
             %?/%t/%e/%; (conditional), %{ (literal int).  */

#include <stdarg.h>

char *
tparm (const char *str, ...)
{
  static char buf[512];
  char *out = buf;
  char *end = buf + sizeof (buf) - 1;
  int params[10] = {0};
  int nparams = 0;
  int stack[32];
  int sp = 0;
  int i;

  /* Collect up to 9 integer parameters.  */
  va_list ap;
  va_start (ap, str);
  for (nparams = 0; nparams < 9; nparams++)
    params[nparams + 1] = va_arg (ap, int);
  va_end (ap);

  const char *p = str;
  while (*p && out < end)
    {
      if (*p != '%')
        {
          *out++ = *p++;
          continue;
        }
      p++;  /* skip '%' */
      switch (*p)
        {
        case 'p':
          p++;
          i = *p++ - '0';
          if (i >= 1 && i <= 9)
            stack[sp++] = params[i];
          break;
        case 'i':
          params[1]++;
          params[2]++;
          p++;
          break;
        case 'd':
          if (sp > 0)
            {
              int n = stack[--sp];
              int written = snprintf (out, (size_t)(end - out), "%d", n);
              if (written > 0)
                out += written;
            }
          p++;
          break;
        case 'o':
          if (sp > 0)
            {
              int n = stack[--sp];
              int written = snprintf (out, (size_t)(end - out), "%o", n);
              if (written > 0)
                out += written;
            }
          p++;
          break;
        case 'x':
          if (sp > 0)
            {
              int n = stack[--sp];
              int written = snprintf (out, (size_t)(end - out), "%x", n);
              if (written > 0)
                out += written;
            }
          p++;
          break;
        case 'c':
          if (sp > 0 && out < end)
            *out++ = (char) stack[--sp];
          p++;
          break;
        case '{':  /* literal integer: %{N} */
          {
            int n = 0;
            p++;
            while (*p && *p != '}')
              {
                n = n * 10 + (*p - '0');
                p++;
              }
            if (*p == '}')
              p++;
            stack[sp++] = n;
          }
          break;
        case '\'':  /* character constant %'X' */
          p++;
          stack[sp++] = (unsigned char)*p;
          if (*p)
            p++;
          if (*p == '\'')
            p++;
          break;
        case '+':
          if (sp >= 2)
            { int b = stack[--sp]; stack[sp - 1] += b; }
          p++;
          break;
        case '-':
          if (sp >= 2)
            { int b = stack[--sp]; stack[sp - 1] -= b; }
          p++;
          break;
        case '*':
          if (sp >= 2)
            { int b = stack[--sp]; stack[sp - 1] *= b; }
          p++;
          break;
        case '/':
          if (sp >= 2)
            { int b = stack[--sp]; if (b) stack[sp - 1] /= b; }
          p++;
          break;
        case 'm':
          if (sp >= 2)
            { int b = stack[--sp]; if (b) stack[sp - 1] %= b; }
          p++;
          break;
        case '&':
          if (sp >= 2)
            { int b = stack[--sp]; stack[sp - 1] &= b; }
          p++;
          break;
        case '|':
          if (sp >= 2)
            { int b = stack[--sp]; stack[sp - 1] |= b; }
          p++;
          break;
        case '^':
          if (sp >= 2)
            { int b = stack[--sp]; stack[sp - 1] ^= b; }
          p++;
          break;
        case '!':
          if (sp > 0)
            stack[sp - 1] = !stack[sp - 1];
          p++;
          break;
        case '~':
          if (sp > 0)
            stack[sp - 1] = ~stack[sp - 1];
          p++;
          break;
        case '<':
          if (sp >= 2)
            { int b = stack[--sp]; int a = stack[--sp]; stack[sp++] = a < b; }
          p++;
          break;
        case '>':
          if (sp >= 2)
            { int b = stack[--sp]; int a = stack[--sp]; stack[sp++] = a > b; }
          p++;
          break;
        case '=':
          if (sp >= 2)
            { int b = stack[--sp]; int a = stack[--sp]; stack[sp++] = a == b; }
          p++;
          break;
        case 'A':  /* logical AND */
          if (sp >= 2)
            { int b = stack[--sp]; stack[sp - 1] = stack[sp - 1] && b; }
          p++;
          break;
        case 'O':  /* logical OR */
          if (sp >= 2)
            { int b = stack[--sp]; stack[sp - 1] = stack[sp - 1] || b; }
          p++;
          break;
        case '?':
          /* Conditional: %?condition%tyes%eno%; or %?cond%tyes%; */
          p++;
          break;
        case 't':
          /* 'then' branch: if top of stack is false, skip until %e or %; */
          if (sp > 0 && !stack[--sp])
            {
              int depth = 1;
              while (*p && depth > 0)
                {
                  if (*p == '%')
                    {
                      p++;
                      if (*p == '?')
                        depth++;
                      else if (*p == ';')
                        depth--;
                      else if (*p == 'e' && depth == 1)
                        { p++; break; }
                    }
                  if (depth > 0)
                    p++;
                }
            }
          else
            {
              p++;
            }
          break;
        case 'e':
          /* 'else' branch: skip until %; */
          {
            int depth = 1;
            while (*p && depth > 0)
              {
                if (*p == '%')
                  {
                    p++;
                    if (*p == '?')
                      depth++;
                    else if (*p == ';')
                      { depth--; if (depth == 0) { p++; break; } }
                  }
                else
                  p++;
              }
          }
          break;
        case ';':
          /* End of conditional.  */
          p++;
          break;
        case 'P':  /* set variable (not needed for our use) */
          p++;
          if (*p)
            p++;
          break;
        case 'g':  /* get variable */
          p++;
          stack[sp++] = 0;
          if (*p)
            p++;
          break;
        case 'l':  /* string length */
          p++;
          break;
        case 's':  /* string push */
          p++;
          break;
        default:
          /* Unknown: output literally.  */
          if (out < end)
            *out++ = '%';
          if (out < end && *p)
            *out++ = *p;
          if (*p)
            p++;
          break;
        }
    }
  *out = '\0';
  return buf;
}

/* ------------------------------------------------------------------ */
/* Readline / other consumers that reference these symbols              */
/* ------------------------------------------------------------------ */

int
tparm_varargs (const char *str, ...)
{
  (void) str;
  return 0;
}
