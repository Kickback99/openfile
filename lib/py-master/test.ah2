#include <py>
#include <log>

logger.info("测试")
logger.info("start")
py.out_str_size := 400
loop(10000)
{
	;py.allspell_muti("@网站文件夹-@网站文件夹-@网站文件夹-@网站文件夹-@网站文件夹-记单词")
	py.allspell_muti("@网站文件夹")
}
logger.info("end")
/*

;多音字，| 分割
;小鹤双拼
msgbox "苟利国家以生死: " py.double_spell_muti("苟利国家以生死")
;全拼
msgbox "苟利国家以生死: " py.allspell_muti("苟利国家以生死")
;简拼
msgbox "苟利国家以生死 " py.initials_muti("苟利国家以生死")
*/