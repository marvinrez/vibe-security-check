// Fixtures that MUST NOT trigger. If a rule fires here it is too broad.
import jwt from "jsonwebtoken";
import { jwtDecode } from "jwt-decode";
import DOMPurify from "dompurify";

const publicUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
const firebaseKey = process.env.NEXT_PUBLIC_FIREBASE_API_KEY;
const mapsKey = import.meta.env.VITE_GOOGLE_MAPS_API_KEY;

async function chat(req: any) {
  return openai.chat.completions.create({ model: "gpt-4", max_tokens: 500, messages: [] });
}
// The client picks a tier; the server's own table says what it costs.
async function chatTier(req: any) {
  return openai.chat.completions.create({ model: MODELS[req.body.tier], messages: req.body.messages });
}
async function chatPlan(req: any) {
  const plan = await prisma.plan.findUnique({ where: { id: req.body.planId } });
  return openai.chat.completions.create({ model: plan.model, max_tokens: plan.maxTokens, messages: [] });
}

async function pay(req: any) {
  const item = await catalogue.find(req.body.itemId);
  return stripe.paymentIntents.create({ amount: item.priceCents, currency: "usd" });
}
async function payPrice(req: any) {
  const price = await stripe.prices.retrieve(req.body.priceId);
  return stripe.paymentIntents.create({ amount: price.unit_amount, currency: "usd" });
}
// Stripe's documented Checkout shape: the client picks one of your price ids, not an amount.
async function checkout(req: any) {
  return stripe.checkout.sessions.create({ line_items: [{ price: req.body.priceId, quantity: 1 }], mode: "payment" });
}

async function save(req: any) {
  return User.update({ name: req.body.name, bio: req.body.bio });
}
export async function PATCH(request: Request) {
  const { name, bio } = await request.json();
  return prisma.user.update({ where: { id: 1 }, data: { name, bio } });
}
// A third-party API response is not the client's request body.
async function cacheRates() {
  const res = await fetch("https://rates.example.com/latest");
  const data = await res.json();
  return prisma.rate.create({ data });
}

const el = document.getElementById("x")!;
el.innerHTML = "<b>static markup</b>";
el.innerHTML = "";
el.innerHTML = DOMPurify.sanitize(userComment);

const claims = jwt.verify(token, process.env.JWT_SECRET!);
// Browser code reading our own token's expiry to schedule a refresh, not an auth decision.
const { exp } = jwtDecode(session.access_token);

const event = stripe.webhooks.constructEvent(req.rawBody, sig, secret);
// Stripe's documented Express handler: express.raw() makes request.body the raw buffer.
app.post("/webhook", express.raw({ type: "application/json" }), (request, response) => {
  const verified = stripe.webhooks.constructEvent(request.body, request.headers["stripe-signature"], secret);
  response.send();
});

app.use(cors({ origin: ["https://app.example.com"], credentials: true }));
app.use(cors({ origin: true }));

async function agentStep(prompt: string) {
  const completion = await openai.chat.completions.create({ model: "gpt-4", messages: [] });
  // The response is parsed into a shape we defined before anything acts on it.
  const { action } = CommandSchema.parse(completion.choices[0].message.content);
  exec(ALLOWED_COMMANDS[action]);
}
async function agentStepStructured() {
  const { object } = await generateObject({ model: agentModel, schema: z.object({ action: z.enum(["list", "status"]) }), prompt: "x" });
  // The response picks an entry; the app supplies the command.
  exec(ALLOWED_COMMANDS[object.action]);
}
async function storeSummary(db: any) {
  const completion = await openai.chat.completions.create({ model: "gpt-4", messages: [] });
  // A bound parameter, not query text.
  await db.query("INSERT INTO summaries (text) VALUES ($1)", [completion.choices[0].message.content]);
}
