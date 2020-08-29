#include <Generic\Queue.mqh>
#include <Generic\Stack.mqh>
#include <Strings\String.mqh>

int rank(char c) {
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

void addValToFunc(string a, CQueue<string> *func) {
  if (a != "X") func.Enqueue(a);
}

void moveOperator(string op, CStack<string> &tok, CStack<string> &val, CQueue<string> *func) {
  string a         = val.Pop();
  bool   negWithOp = op == "|" && (tok.Count() > 0 && tok.Peek() != "(");
  if (op != "|" || negWithOp) addValToFunc(val.Pop(), func);
  addValToFunc(a, func);
  func.Enqueue(op);
  if (negWithOp) func.Enqueue(tok.Pop());
  val.Push("X");
}

void parseExp(string value, string &alpha, CQueue<string> *&func) {
  alpha = value;
  func  = new CQueue<string>(100);

  if (value == "") return;

  CStack<string> tok(100);
  CStack<string> val(100);

  StringReplace(alpha, " ", "");
  // Print("T ", alpha);

  int l = StringLen(alpha);
  for (int i = 0; i < l; ++i) {
    char   c  = alpha[i];
    string cs = StringSubstr(alpha, i, 1);

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
          if (p != '(' && rank(p) > rank(c)) {
            string t = tok.Pop();
            moveOperator(t, tok, val, func);
          }
        }
      case '(':
        tok.Push(cs);
        break;
      case ')': {
        string t = tok.Pop();
        while (t != "(") {
          moveOperator(t, tok, val, func);
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
        while (i < l && alpha[i] >= '0' && alpha[i] <= '9') ++i;
        val.Push(StringSubstr(alpha, j, i - j));
        --i;
        break;
      }
      default:
        break;
    }
  }

  while (tok.Count() > 0) {
    addValToFunc(val.Pop(), func);
    func.Enqueue(tok.Pop());
  }

  //   Print("TOK ", tok.Log());
  //   Print("VAL ", val.Log());
  //   Print("FUNC ", func.Log());
}
