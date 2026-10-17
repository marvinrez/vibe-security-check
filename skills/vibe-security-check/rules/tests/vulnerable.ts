// Fixtures that MUST trigger. A "ruleid:" comment names the rule that has to fire on the line
// below it, and rules/tests/check.py fails on any finding that is not annotated.
import jwt from "jsonwebtoken";
import { jwtDecode } from "jwt-decode";

// ruleid: service-role-key-outside-server
const admin = process.env.SUPABASE_SERVICE_ROLE_KEY;
// ruleid: service-role-key-outside-server
const secretKey = process.env.SUPABASE_SECRET_KEY;

// ruleid: public-prefixed-secret
const leaked = process.env.NEXT_PUBLIC_STRIPE_SECRET_KEY;
// ruleid: public-prefixed-secret
const modelKey = import.meta.env.VITE_OPENAI_API_KEY;
// ruleid: public-prefixed-secret
const firebaseAdmin = process.env.NEXT_PUBLIC_FIREBASE_PRIVATE_KEY;

async function chat(req: any) {
  // ruleid: cost-parameter-from-client
  return openai.chat.completions.create({ model: req.body.model, messages: [] });
}
async function chat2(req: any) {
  // ruleid: cost-parameter-from-client
  return openai.chat.completions.create({ model: "gpt-4", max_tokens: req.body.max_tokens });
}
async function chat3(req: any) {
  const { model, max_tokens } = req.body;
  // ruleid: cost-parameter-from-client
  return openai.chat.completions.create({ model, max_tokens, messages: [] });
}
// A Next.js route handler has no req.body, only await request.json().
export async function POST(request: Request) {
  const body = await request.json();
  // ruleid: cost-parameter-from-client
  return generateText({ model: openai(body.model), maxOutputTokens: body.limit, prompt: body.prompt });
}

async function pay(req: any) {
  // ruleid: price-from-client
  return stripe.paymentIntents.create({ amount: req.body.amount, currency: "usd" });
}
async function pay2(req: any) {
  // ruleid: price-from-client
  return stripe.paymentIntents.create({ amount: Math.round(req.body.price * 100), currency: "usd" });
}

async function save(req: any) {
  // ruleid: mass-assignment-from-body
  return User.update(req.body);
}
async function savePrisma(req: any) {
  // ruleid: mass-assignment-from-body
  return prisma.user.update({ where: { id: req.params.id }, data: req.body });
}
async function saveMongoose(req: any) {
  // ruleid: mass-assignment-from-body
  return User.findByIdAndUpdate(req.params.id, req.body, { new: true });
}
async function saveSpread(req: any) {
  // ruleid: mass-assignment-from-body
  return User.create({ ...req.body, ownerId: req.user.id });
}
export async function PATCH(request: Request) {
  const updates = await request.json();
  // ruleid: mass-assignment-from-body
  return db.update(users).set(updates).where(eq(users.id, 1));
}

const el = document.getElementById("x")!;
// ruleid: raw-html-with-variable
el.innerHTML = userComment;
// ruleid: raw-html-with-variable
el.insertAdjacentHTML("beforeend", userComment);

// ruleid: tls-verification-disabled
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

// ruleid: webhook-signature-against-parsed-body
const event = stripe.webhooks.constructEvent(req.body, sig, secret);
async function nextWebhook(request: Request) {
  const payload = await request.json();
  // ruleid: webhook-signature-against-parsed-body
  return stripe.webhooks.constructEvent(JSON.stringify(payload), sig, secret);
}

// ruleid: jwt-decoded-without-verification
const claims = jwt.decode(token);
export function middleware(request: NextRequest) {
  // ruleid: jwt-decoded-without-verification
  const { role } = jwtDecode(request.cookies.get("token")!.value);
  if (role !== "admin") return NextResponse.redirect(new URL("/", request.url));
}
app.get("/admin", (req, res) => {
  // ruleid: jwt-decoded-without-verification
  const user = jwtDecode(req.headers.authorization!);
  res.json(user);
});

// ruleid: permissive-cors-with-credentials
app.use(cors({ origin: true, credentials: true }));
// ruleid: permissive-cors-with-credentials
app.use(cors({ origin: "*", credentials: true }));

async function agentStep(prompt: string) {
  const completion = await openai.chat.completions.create({ model: "gpt-4", messages: [] });
  const command = completion.choices[0].message.content;
  // ruleid: model-output-into-sink
  exec(command);
}
async function agentStepParsed() {
  const completion = await openai.chat.completions.create({ model: "gpt-4", messages: [] });
  // JSON.parse checks no shape, so the command is still the model's.
  const { cmd } = JSON.parse(completion.choices[0].message.content!);
  // ruleid: model-output-into-sink
  exec(cmd);
}
async function renderAnswer(target: HTMLElement) {
  const { text } = await generateText({ model: answerModel, prompt: "x" });
  // ruleid: model-output-into-sink, raw-html-with-variable
  target.innerHTML = marked.parse(text);
}
async function searchNotes(db: any) {
  const completion = await openai.chat.completions.create({ model: "gpt-4", messages: [] });
  // ruleid: model-output-into-sink
  await db.query(`SELECT * FROM notes WHERE ${completion.choices[0].message.content}`);
}
