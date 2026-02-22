import 'daily_text.dart';
import '../services/app_language.dart';

const List<DailyText> _hadithEnglish = [
  DailyText(
    title: 'Hadith of the Day',
    text: 'Actions are judged by intentions, and every person will get the reward according to what they intended.',
    source: 'Bukhari & Muslim',
  ),
  DailyText(
    title: 'Hadith of the Day',
    text: 'The most beloved deeds to Allah are those that are most consistent, even if small.',
    source: 'Bukhari & Muslim',
  ),
  DailyText(
    title: 'Hadith of the Day',
    text: 'Whoever believes in Allah and the Last Day should speak good or remain silent.',
    source: 'Bukhari & Muslim',
  ),
  DailyText(
    title: 'Hadith of the Day',
    text: 'The strong person is not the one who overcomes people by strength, but the one who controls himself while in anger.',
    source: 'Bukhari & Muslim',
  ),
  DailyText(
    title: 'Hadith of the Day',
    text: 'None of you truly believes until he loves for his brother what he loves for himself.',
    source: 'Bukhari & Muslim',
  ),
  DailyText(
    title: 'Hadith of the Day',
    text: 'The merciful are shown mercy by the Most Merciful. Be merciful to those on earth and the One above the heavens will be merciful to you.',
    source: 'Tirmidhi',
  ),
  DailyText(
    title: 'Hadith of the Day',
    text: 'Whoever relieves a believer of hardship in this world, Allah will relieve him of hardship on the Day of Resurrection.',
    source: 'Muslim',
  ),
  DailyText(
    title: 'Hadith of the Day',
    text: 'Purity is half of faith.',
    source: 'Muslim',
  ),
  DailyText(
    title: 'Hadith of the Day',
    text: 'A good word is charity.',
    source: 'Bukhari & Muslim',
  ),
  DailyText(
    title: 'Hadith of the Day',
    text: 'Whoever does not thank people has not thanked Allah.',
    source: 'Tirmidhi',
  ),
  DailyText(
    title: 'Hadith of the Day',
    text: 'The best among you are those who learn the Quran and teach it.',
    source: 'Bukhari',
  ),
  DailyText(
    title: 'Hadith of the Day',
    text: 'Allah is gentle and loves gentleness in all matters.',
    source: 'Bukhari & Muslim',
  ),
  DailyText(
    title: 'Hadith of the Day',
    text: 'Whoever treads a path seeking knowledge, Allah will make easy for him a path to Paradise.',
    source: 'Muslim',
  ),
];

const List<DailyText> _hadithAmharic = [
  DailyText(
    title: 'የዛሬ ሐዲስ',
    text: 'ተግባሮች በነየት ይመዘናሉ፤ ለእያንዳንዱም ሰው ያሰበው ይሆናል።',
    source: 'ቡኻሪ እና ሙስሊም',
  ),
  DailyText(
    title: 'የዛሬ ሐዲስ',
    text: 'ለአላህ ከሁሉ የተወደዱ ሥራዎች ቢትንሽም በቀጣይነት የሚደረጉት ናቸው።',
    source: 'ቡኻሪ እና ሙስሊም',
  ),
  DailyText(
    title: 'የዛሬ ሐዲስ',
    text: 'በአላህና በመጨረሻው ቀን የሚያምን ሰው መልካም ቃል ይናገር ወይም ዝም ይበል።',
    source: 'ቡኻሪ እና ሙስሊም',
  ),
  DailyText(
    title: 'የዛሬ ሐዲስ',
    text: 'ብርቱ ሰው ሌሎችን በጉልበት የሚያሸንፍ ሳይሆን በቁጣ ጊዜ ራሱን የሚቆጣጠር ነው።',
    source: 'ቡኻሪ እና ሙስሊም',
  ),
  DailyText(
    title: 'የዛሬ ሐዲስ',
    text: 'ለወንድሙ ራሱ የሚወደውን እስኪወድድ ድረስ እውነተኛ እምነት አይሞላበትም።',
    source: 'ቡኻሪ እና ሙስሊም',
  ),
  DailyText(
    title: 'የዛሬ ሐዲስ',
    text: 'ርህራሄ ያላቸውን አር-ረህማን ይራራላቸዋል፤ በምድር ላይ ለሰዎች ይራሩ ከሰማይ ያለው ይራራላችኋል።',
    source: 'ቲርሚዚ',
  ),
  DailyText(
    title: 'የዛሬ ሐዲስ',
    text: 'በዚህ ዓለም ከሙእሚን አንድ ችግር ያስወገደ ሰው፣ አላህ በትንሣኤ ቀን ከችግሮቹ ያስወግደዋል።',
    source: 'ሙስሊም',
  ),
  DailyText(
    title: 'የዛሬ ሐዲስ',
    text: 'ንፅህና የእምነት ግማሽ ናት።',
    source: 'ሙስሊም',
  ),
  DailyText(
    title: 'የዛሬ ሐዲስ',
    text: 'መልካም ቃል ሰደቃ ነው።',
    source: 'ቡኻሪ እና ሙስሊም',
  ),
  DailyText(
    title: 'የዛሬ ሐዲስ',
    text: 'ለሰዎች የማያመሰግን ሰው ለአላህም አያመሰግንም።',
    source: 'ቲርሚዚ',
  ),
  DailyText(
    title: 'የዛሬ ሐዲስ',
    text: 'ከእናንተ ምርጦች ቁርአንን የሚማሩና የሚያስተምሩ ናቸው።',
    source: 'ቡኻሪ',
  ),
  DailyText(
    title: 'የዛሬ ሐዲስ',
    text: 'አላህ ለስላሳ ነው፤ በሁሉም ጉዳይ ለስላሳነትን ይወዳል።',
    source: 'ቡኻሪ እና ሙስሊም',
  ),
  DailyText(
    title: 'የዛሬ ሐዲስ',
    text: 'እውቀት ለመፈለግ መንገድ የሚጓዝ ሰው አላህ ወደ ጀነት መንገድ ያቀላልለታል።',
    source: 'ሙስሊም',
  ),
];

List<DailyText> hadithForLanguage(AppLanguage language) {
  switch (language) {
    case AppLanguage.amharic:
      return _hadithAmharic;
    case AppLanguage.english:
      return _hadithEnglish;
  }
}

const List<DailyText> hadith = _hadithEnglish;
