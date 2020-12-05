#include <Generic\ArrayList.mqh>
#include <Generic\Queue.mqh>
#include <Generic\Stack.mqh>
#include <Strings\String.mqh>

int Rank(char c) {
  switch (c) {
    case '+':
    case '-':
      return 1;
    case '*':
    case '/':
      return 2;
    case '|':
      return 6;
    default:
      return 0;
  }
}

void AddToFunc(string a, CArrayList<string> *func) {
  if (a != "X") func.Add(a);
}

void MoveOperator(string op, CStack<string> &tok, CStack<string> &val, CArrayList<string> *func) {
  string a         = val.Pop();
  bool   negWithOp = op == "|" && (tok.Count() > 0 && tok.Peek() != "(");
  if (op != "|" || negWithOp) AddToFunc(val.Pop(), func);
  AddToFunc(a, func);
  AddToFunc(op, func);
  if (negWithOp) AddToFunc(tok.Pop(), func);
  val.Push("X");
}

void ParseExp(string value, CArrayList<string> *&func) {
  func = new CArrayList<string>(100);

  if (value == "") return;

  string         alpha = value;
  CStack<string> tok(100);
  CStack<string> val(100);

  StringReplace(alpha, " ", "");
  // Print("T ", alpha);

  int l = StringLen(alpha);
  for (int i = 0; i < l; ++i) {
    char   c  = alpha[i];
    string cs = StringSubstr(alpha, i, 1);

    // Print("C ", cs);
    // Print("TOK ", tok.Log());
    // Print("VAL ", val.Log());
    // Print("FUNC ", func.Log());
    // Print("-------");
    switch (c) {
      case '+':
        if (i == 0 || alpha[i - 1] == '+' || alpha[i - 1] == '-' || alpha[i - 1] == '*' || alpha[i - 1] == '/' ||
            alpha[i - 1] == '(')
          continue;
      case '-':
        if (i == 0 || alpha[i - 1] == '+' || alpha[i - 1] == '-' || alpha[i - 1] == '*' || alpha[i - 1] == '/' ||
            alpha[i - 1] == '(') {
          cs = "|";
          c  = '|';
        }
      case '*':
      case '/':
        if (tok.Count() > 0) {
          char p = tok.Peek()[0];
          if (p != '(' && Rank(p) > Rank(c)) {
            string t = tok.Pop();
            MoveOperator(t, tok, val, func);
          }
        }
      case '(':
        tok.Push(cs);
        break;
      case ')': {
        string t = tok.Pop();
        while (t != "(") {
          MoveOperator(t, tok, val, func);
          t = tok.Pop();
        }
        break;
      }
      case 'R':
      case 'C':
      case 'O':
      case 'H':
      case 'L':
      case '0':
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
      case '8':
      case '9': {
        int j = i++;
        while (i < l && ((alpha[i] >= '0' && alpha[i] <= '9') || alpha[i] == '.')) ++i;
        val.Push(StringSubstr(alpha, j, i - j));
        --i;
        break;
      }
      default:
        break;
    }
  }

  // Print("TOK ", tok.Log());
  // Print("VAL ", val.Log());
  // Print("FUNC ", func.Log());
  // Print("-------");

  while (tok.Count() > 0) {
    MoveOperator(tok.Pop(), tok, val, func);
  }

  if (func.Count() == 0 && val.Count() == 1) {
    AddToFunc(val.Pop(), func);
  }

  // Print("TOK ", tok.Log());
  // Print("VAL ", val.Log());
  // Print("FUNC ", func.Log());
}
