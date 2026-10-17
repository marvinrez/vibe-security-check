// JSX fixtures that MUST trigger. See vulnerable.ts for the annotation format.
export function Comment({ html }: { html: string }) {
  // ruleid: raw-html-with-variable
  return <div dangerouslySetInnerHTML={{ __html: html }} />;
}

export async function Answer() {
  const completion = await openai.chat.completions.create({ model: "gpt-4", messages: [] });
  // ruleid: model-output-into-sink, raw-html-with-variable
  return <div dangerouslySetInnerHTML={{ __html: completion.choices[0].message.content }} />;
}
